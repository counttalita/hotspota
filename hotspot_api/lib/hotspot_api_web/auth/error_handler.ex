defmodule HotspotApiWeb.Auth.ErrorHandler do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, _reason}, _opts) do
    body = %{
      error: %{
        code: to_string(type),
        message: auth_error_message(type),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }

    conn
    |> put_status(401)
    |> json(body)
  end

  defp auth_error_message(:invalid_token), do: "Invalid authentication token"
  defp auth_error_message(:token_expired), do: "Authentication token has expired"
  defp auth_error_message(:unauthenticated), do: "Authentication required"
  defp auth_error_message(_), do: "Authentication failed"
end
