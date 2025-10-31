defmodule HotspotApiWeb.Plugs.PremiumRequired do
  @moduledoc """
  Plug to ensure the current user has an active premium subscription.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias HotspotApi.Guardian

  def init(opts), do: opts

  def call(conn, _opts) do
    user = Guardian.Plug.current_resource(conn)

    cond do
      is_nil(user) ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
        |> halt()

      not user.is_premium ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: "Premium subscription required",
          message: "This feature is only available to premium users. Upgrade your subscription to access this feature."
        })
        |> halt()

      premium_expired?(user) ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: "Premium subscription expired",
          message: "Your premium subscription has expired. Please renew to continue accessing premium features."
        })
        |> halt()

      true ->
        conn
    end
  end

  defp premium_expired?(%{premium_expires_at: nil}), do: false
  defp premium_expired?(%{premium_expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end
end
