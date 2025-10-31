defmodule HotspotApi.Subscriptions do
  @moduledoc """
  The Subscriptions context for managing premium subscriptions via Paystack.
  """

  import Ecto.Query, warn: false
  alias HotspotApi.Repo
  alias HotspotApi.Accounts
  alias HotspotApi.Accounts.Subscription

  @paystack_base_url "https://api.paystack.co"

  @doc """
  Initialize a new subscription for a user.
  Creates a Paystack subscription and returns the authorization URL.
  """
  def initialize_subscription(user_id, plan_type) when plan_type in ["monthly", "annual"] do
    user = Accounts.get_user!(user_id)
    amount = Subscription.plan_amount(plan_type)

    # Create subscription record
    subscription_attrs = %{
      user_id: user_id,
      plan_type: plan_type,
      status: "pending",
      amount: amount,
      currency: "ZAR"
    }

    with {:ok, subscription} <- create_subscription(subscription_attrs),
         {:ok, paystack_response} <- initialize_paystack_transaction(user, subscription) do
      # Update subscription with Paystack details
      update_subscription(subscription, %{
        paystack_authorization_code: paystack_response["reference"]
      })

      {:ok, %{
        subscription_id: subscription.id,
        authorization_url: paystack_response["authorization_url"],
        reference: paystack_response["reference"]
      }}
    end
  end

  defp initialize_paystack_transaction(user, subscription) do
    email = user.email || "#{user.phone_number}@hotspot.app"

    payload = %{
      email: email,
      amount: subscription.amount,
      currency: subscription.currency,
      reference: generate_reference(subscription.id),
      callback_url: callback_url(),
      metadata: %{
        subscription_id: subscription.id,
        user_id: user.id,
        plan_type: subscription.plan_type
      }
    }

    case make_paystack_request("POST", "/transaction/initialize", payload) do
      {:ok, %{"status" => true, "data" => data}} -> {:ok, data}
      {:ok, %{"status" => false, "message" => message}} -> {:error, message}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Handle Paystack webhook events.
  Verifies the webhook signature and processes the event.
  """
  def handle_webhook(payload, signature) do
    if verify_webhook_signature(payload, signature) do
      event = Jason.decode!(payload)
      process_webhook_event(event)
    else
      {:error, :invalid_signature}
    end
  end

  defp process_webhook_event(%{"event" => "charge.success", "data" => data}) do
    reference = data["reference"]

    case get_subscription_by_reference(reference) do
      nil -> {:error, :subscription_not_found}
      subscription -> activate_subscription(subscription, data)
    end
  end

  defp process_webhook_event(%{"event" => "subscription.disable", "data" => data}) do
    subscription_code = data["subscription_code"]

    case get_subscription_by_code(subscription_code) do
      nil -> {:error, :subscription_not_found}
      subscription -> deactivate_subscription(subscription)
    end
  end

  defp process_webhook_event(_event), do: {:ok, :ignored}

  defp activate_subscription(subscription, paystack_data) do
    # Calculate expiration date based on plan type
    expires_at = calculate_expiration_date(subscription.plan_type)

    attrs = %{
      status: "active",
      paystack_subscription_code: paystack_data["subscription_code"],
      paystack_customer_code: paystack_data["customer"]["customer_code"],
      expires_at: expires_at,
      next_payment_date: expires_at
    }

    with {:ok, subscription} <- update_subscription(subscription, attrs),
         {:ok, _user} <- Accounts.update_user_premium_status(subscription.user_id, true, expires_at) do
      {:ok, subscription}
    end
  end

  defp deactivate_subscription(subscription) do
    attrs = %{
      status: "cancelled",
      cancelled_at: DateTime.utc_now()
    }

    with {:ok, subscription} <- update_subscription(subscription, attrs),
         {:ok, _user} <- Accounts.update_user_premium_status(subscription.user_id, false, nil) do
      {:ok, subscription}
    end
  end

  @doc """
  Get the current subscription status for a user.
  """
  def get_user_subscription(user_id) do
    Repo.one(
      from s in Subscription,
        where: s.user_id == ^user_id,
        where: s.status in ["active", "pending"],
        order_by: [desc: s.inserted_at],
        limit: 1
    )
  end

  @doc """
  Cancel a user's subscription.
  """
  def cancel_subscription(user_id, reason \\ nil) do
    case get_user_subscription(user_id) do
      nil -> {:error, :no_active_subscription}
      subscription ->
        # Cancel on Paystack if we have a subscription code
        if subscription.paystack_subscription_code do
          cancel_paystack_subscription(subscription.paystack_subscription_code)
        end

        # Update local subscription
        attrs = %{
          status: "cancelled",
          cancelled_at: DateTime.utc_now(),
          cancellation_reason: reason
        }

        with {:ok, subscription} <- update_subscription(subscription, attrs),
             {:ok, _user} <- Accounts.update_user_premium_status(user_id, false, nil) do
          {:ok, subscription}
        end
    end
  end

  defp cancel_paystack_subscription(subscription_code) do
    payload = %{
      code: subscription_code,
      token: get_paystack_email_token()
    }

    make_paystack_request("POST", "/subscription/disable", payload)
  end

  @doc """
  List all subscription plans with pricing.
  """
  def list_plans do
    [
      %{
        id: "monthly",
        name: "Monthly Premium",
        price: 99.00,
        currency: "ZAR",
        interval: "monthly",
        features: [
          "Extended alert radius (up to 10km)",
          "City-wide analytics",
          "Travel Mode with route safety",
          "Background notifications",
          "SOS with trusted contacts",
          "Advance hotspot zone warnings"
        ]
      },
      %{
        id: "annual",
        name: "Annual Premium",
        price: 990.00,
        currency: "ZAR",
        interval: "annual",
        savings: "17% off (2 months free)",
        features: [
          "All monthly features",
          "17% discount",
          "Priority support"
        ]
      }
    ]
  end

  # Private helper functions

  defp create_subscription(attrs) do
    %Subscription{}
    |> Subscription.changeset(attrs)
    |> Repo.insert()
  end

  defp update_subscription(%Subscription{} = subscription, attrs) do
    subscription
    |> Subscription.changeset(attrs)
    |> Repo.update()
  end

  defp get_subscription_by_reference(reference) do
    # Extract subscription_id from reference
    case String.split(reference, "_") do
      ["SUB", id | _] -> Repo.get(Subscription, id)
      _ -> nil
    end
  end

  defp get_subscription_by_code(subscription_code) do
    Repo.one(
      from s in Subscription,
        where: s.paystack_subscription_code == ^subscription_code,
        limit: 1
    )
  end

  defp calculate_expiration_date("monthly") do
    DateTime.utc_now() |> DateTime.add(30, :day)
  end

  defp calculate_expiration_date("annual") do
    DateTime.utc_now() |> DateTime.add(365, :day)
  end

  defp generate_reference(subscription_id) do
    "SUB_#{subscription_id}_#{:os.system_time(:millisecond)}"
  end

  defp callback_url do
    Application.get_env(:hotspot_api, :paystack_callback_url, "https://hotspot.app/payment/callback")
  end

  defp make_paystack_request(method, path, payload) do
    url = @paystack_base_url <> path
    secret_key = Application.get_env(:hotspot_api, :paystack_secret_key)

    headers = [
      {"Authorization", "Bearer #{secret_key}"},
      {"Content-Type", "application/json"}
    ]

    body = Jason.encode!(payload)

    case HTTPoison.request(method, url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}
      {:ok, %HTTPoison.Response{status_code: status, body: response_body}} ->
        {:error, "Paystack API error: #{status} - #{response_body}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp verify_webhook_signature(payload, signature) do
    secret_key = Application.get_env(:hotspot_api, :paystack_secret_key)

    computed_signature =
      :crypto.mac(:hmac, :sha512, secret_key, payload)
      |> Base.encode16(case: :lower)

    computed_signature == signature
  end

  defp get_paystack_email_token do
    # Paystack requires an email token for subscription cancellation
    # This should be obtained from the customer's email
    Application.get_env(:hotspot_api, :paystack_email_token, "")
  end
end
