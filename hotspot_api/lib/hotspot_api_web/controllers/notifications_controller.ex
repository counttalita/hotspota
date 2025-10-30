defmodule HotspotApiWeb.NotificationsController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Notifications
  alias HotspotApi.Guardian

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  Register FCM token for push notifications
  POST /api/notifications/register-token
  """
  def register_token(conn, %{"token" => token, "platform" => platform}) do
    with {:ok, user_id} <- get_current_user_id(conn),
         {:ok, fcm_token} <- Notifications.register_token(user_id, token, platform) do
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        message: "Token registered successfully",
        data: %{
          id: fcm_token.id,
          platform: fcm_token.platform
        }
      })
    end
  end

  def register_token(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required fields: token and platform"})
  end

  @doc """
  Get notification preferences
  GET /api/notifications/preferences
  """
  def get_preferences(conn, _params) do
    with {:ok, user_id} <- get_current_user_id(conn) do
      user = HotspotApi.Accounts.get_user!(user_id)

      preferences = %{
        alert_radius: user.alert_radius,
        notification_config: user.notification_config || %{},
        is_premium: user.is_premium
      }

      json(conn, %{success: true, data: preferences})
    end
  end

  @doc """
  Update notification preferences
  PUT /api/notifications/preferences
  """
  def update_preferences(conn, params) do
    with {:ok, user_id} <- get_current_user_id(conn) do
      user = HotspotApi.Accounts.get_user!(user_id)

      # Build update attributes
      attrs = %{}

      attrs =
        if Map.has_key?(params, "alert_radius") do
          # Enforce radius limits based on premium status
          max_radius = if user.is_premium, do: 10000, else: 2000
          radius = min(params["alert_radius"], max_radius)
          Map.put(attrs, :alert_radius, radius)
        else
          attrs
        end

      attrs =
        if Map.has_key?(params, "notification_config") do
          Map.put(attrs, :notification_config, params["notification_config"])
        else
          attrs
        end

      case HotspotApi.Accounts.update_user(user, attrs) do
        {:ok, updated_user} ->
          json(conn, %{
            success: true,
            message: "Preferences updated successfully",
            data: %{
              alert_radius: updated_user.alert_radius,
              notification_config: updated_user.notification_config
            }
          })

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Failed to update preferences", details: format_errors(changeset)})
      end
    end
  end

  # Helper to get current user ID from Guardian token
  defp get_current_user_id(conn) do
    case Guardian.Plug.current_resource(conn) do
      nil -> {:error, :unauthorized}
      user -> {:ok, user.id}
    end
  end

  # Format changeset errors
  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
