defmodule HotspotApiWeb.Admin.DashboardController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Admin
  alias HotspotApi.Guardian

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  Get dashboard statistics
  GET /api/admin/dashboard/stats
  """
  def stats(conn, _params) do
    admin = Guardian.Plug.current_resource(conn)

    stats = Admin.get_dashboard_stats()

    # Log admin action
    Admin.log_audit(admin.id, "view_dashboard_stats", "dashboard", nil, %{}, get_ip_address(conn))

    conn
    |> put_status(:ok)
    |> json(%{data: stats})
  end

  @doc """
  Get real-time activity feed
  GET /api/admin/dashboard/activity
  """
  def activity(conn, params) do
    admin = Guardian.Plug.current_resource(conn)
    limit = Map.get(params, "limit", "20") |> String.to_integer()

    activities = Admin.get_recent_activity(limit)

    # Log admin action
    Admin.log_audit(admin.id, "view_activity_feed", "dashboard", nil, %{limit: limit}, get_ip_address(conn))

    conn
    |> put_status(:ok)
    |> json(%{data: activities})
  end

  defp get_ip_address(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> to_string(:inet.ntoa(conn.remote_ip))
    end
  end
end
