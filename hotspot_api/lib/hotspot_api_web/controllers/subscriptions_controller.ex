defmodule HotspotApiWeb.SubscriptionsController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Subscriptions
  alias HotspotApi.Guardian

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  Initialize a new subscription.
  POST /api/subscriptions/initialize
  """
  def initialize(conn, %{"plan_type" => plan_type}) do
    user = Guardian.Plug.current_resource(conn)

    case Subscriptions.initialize_subscription(user.id, plan_type) do
      {:ok, result} ->
        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          data: result
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: format_error(reason)
        })
    end
  end

  @doc """
  Handle Paystack webhook events.
  POST /api/subscriptions/webhook
  """
  def webhook(conn, _params) do
    # Get the raw body and signature
    signature = get_req_header(conn, "x-paystack-signature") |> List.first()
    {:ok, body, _conn} = Plug.Conn.read_body(conn)

    case Subscriptions.handle_webhook(body, signature) do
      {:ok, _result} ->
        conn
        |> put_status(:ok)
        |> json(%{success: true})

      {:error, :invalid_signature} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "Invalid signature"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, error: format_error(reason)})
    end
  end

  @doc """
  Get current subscription status for the authenticated user.
  GET /api/subscriptions/status
  """
  def status(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    case Subscriptions.get_user_subscription(user.id) do
      nil ->
        conn
        |> json(%{
          success: true,
          data: %{
            has_subscription: false,
            is_premium: user.is_premium,
            plan_type: nil,
            status: nil,
            expires_at: nil
        }
        })

      subscription ->
        conn
        |> json(%{
          success: true,
          data: %{
            has_subscription: true,
            is_premium: user.is_premium,
            plan_type: subscription.plan_type,
            status: subscription.status,
            expires_at: subscription.expires_at,
            next_payment_date: subscription.next_payment_date,
            amount: subscription.amount / 100.0,
            currency: subscription.currency
          }
        })
    end
  end

  @doc """
  Cancel the user's subscription.
  POST /api/subscriptions/cancel
  """
  def cancel(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    reason = Map.get(params, "reason")

    case Subscriptions.cancel_subscription(user.id, reason) do
      {:ok, _subscription} ->
        conn
        |> json(%{
          success: true,
          message: "Subscription cancelled successfully"
        })

      {:error, :no_active_subscription} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "No active subscription found"
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: format_error(reason)
        })
    end
  end

  @doc """
  List available subscription plans.
  GET /api/subscriptions/plans
  """
  def plans(conn, _params) do
    plans = Subscriptions.list_plans()

    conn
    |> json(%{
      success: true,
      data: plans
    })
  end

  defp format_error(error) when is_atom(error), do: error |> Atom.to_string() |> String.replace("_", " ")
  defp format_error(error) when is_binary(error), do: error
  defp format_error(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
  defp format_error(error), do: inspect(error)
end
