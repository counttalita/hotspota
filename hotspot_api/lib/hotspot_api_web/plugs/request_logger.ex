defmodule HotspotApiWeb.Plugs.RequestLogger do
  @moduledoc """
  Logs all API requests and responses for forensic analysis and security auditing.
  """

  require Logger
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time()

    Plug.Conn.register_before_send(conn, fn conn ->
      duration = System.monotonic_time() - start_time
      duration_ms = System.convert_time_unit(duration, :native, :millisecond)

      log_request(conn, duration_ms)
      conn
    end)
  end

  defp log_request(conn, duration_ms) do
    user_id = get_user_id(conn)
    ip_address = HotspotApi.Security.get_ip_address(conn)

    metadata = %{
      method: conn.method,
      path: conn.request_path,
      status: conn.status,
      duration_ms: duration_ms,
      ip_address: ip_address,
      user_id: user_id,
      user_agent: get_user_agent(conn),
      query_string: conn.query_string,
      timestamp: DateTime.utc_now()
    }

    # Log at different levels based on status code
    case conn.status do
      status when status >= 500 ->
        Logger.error("API Request", metadata)

      status when status >= 400 ->
        Logger.warning("API Request", metadata)

      _ ->
        Logger.info("API Request", metadata)
    end

    # Store security-relevant requests in database
    if should_store_in_db?(conn) do
      HotspotApi.Security.log_event(%{
        event_type: "api_request",
        user_id: user_id,
        ip_address: ip_address,
        user_agent: get_user_agent(conn),
        details: %{
          method: conn.method,
          path: conn.request_path,
          status: conn.status,
          duration_ms: duration_ms
        },
        severity: get_severity(conn.status)
      })
    end
  end

  defp get_user_id(conn) do
    case conn.assigns[:current_user] do
      nil -> nil
      user -> user.id
    end
  end

  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [user_agent | _] -> user_agent
      [] -> nil
    end
  end

  defp should_store_in_db?(conn) do
    # Store failed auth attempts, errors, and suspicious activity
    conn.status >= 400 or
      String.contains?(conn.request_path, "/auth/") or
      String.contains?(conn.request_path, "/admin/")
  end

  defp get_severity(status) when status >= 500, do: "high"
  defp get_severity(status) when status >= 400, do: "medium"
  defp get_severity(_), do: "low"
end
