defmodule HotspotApiWeb.Plugs.CSRFProtection do
  @moduledoc """
  CSRF protection for state-changing API operations.
  Validates CSRF tokens for POST, PUT, PATCH, DELETE requests.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    if state_changing_request?(conn) and not exempt_path?(conn) do
      validate_csrf_token(conn)
    else
      conn
    end
  end

  defp state_changing_request?(conn) do
    conn.method in ["POST", "PUT", "PATCH", "DELETE"]
  end

  defp exempt_path?(conn) do
    # Exempt certain paths from CSRF protection (e.g., webhook endpoints)
    exempt_paths = [
      "/api/subscriptions/webhook",
      "/api/notifications/fcm-callback"
    ]

    Enum.any?(exempt_paths, &String.starts_with?(conn.request_path, &1))
  end

  defp validate_csrf_token(conn) do
    token = get_csrf_token(conn)

    if valid_token?(token) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Invalid or missing CSRF token"})
      |> halt()
    end
  end

  defp get_csrf_token(conn) do
    # Check header first, then params
    case get_req_header(conn, "x-csrf-token") do
      [token | _] -> token
      [] -> conn.params["_csrf_token"]
    end
  end

  defp valid_token?(nil), do: false

  defp valid_token?(token) do
    # For API-only apps, we can use a simpler token validation
    # In production, you might want to use Phoenix.Token or similar
    case Plug.CSRFProtection.get_csrf_token() do
      ^token -> true
      _ -> false
    end
  end

  @doc """
  Generates a CSRF token for the current session.
  """
  def generate_token do
    Plug.CSRFProtection.get_csrf_token()
  end
end
