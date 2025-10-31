defmodule HotspotApiWeb.Admin.AnalyticsController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Admin
  alias HotspotApi.Guardian

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  GET /api/admin/analytics/trends
  Returns incident trends over time grouped by type.
  Query params: start_date, end_date (ISO8601 format)
  """
  def trends(conn, params) do
    admin = Guardian.Plug.current_resource(conn)

    with {:ok, start_date, end_date} <- parse_date_range(params) do
      trends = Admin.get_analytics_trends(start_date, end_date)

      # Log admin action
      Admin.log_audit(admin.id, "view_analytics_trends", "analytics", nil, %{start_date: start_date, end_date: end_date}, get_ip_address(conn))

      conn
      |> put_status(:ok)
      |> json(%{data: trends})
    end
  end

  @doc """
  GET /api/admin/analytics/heatmap
  Returns geographic heatmap data for incident density visualization.
  Query params: start_date, end_date (ISO8601 format)
  """
  def heatmap(conn, params) do
    admin = Guardian.Plug.current_resource(conn)

    with {:ok, start_date, end_date} <- parse_date_range(params) do
      heatmap_data = Admin.get_analytics_heatmap(start_date, end_date)

      # Log admin action
      Admin.log_audit(admin.id, "view_analytics_heatmap", "analytics", nil, %{start_date: start_date, end_date: end_date}, get_ip_address(conn))

      conn
      |> put_status(:ok)
      |> json(%{data: heatmap_data})
    end
  end

  @doc """
  GET /api/admin/analytics/peak-hours
  Returns peak hours analysis showing when incidents occur most frequently.
  Query params: start_date, end_date (ISO8601 format)
  """
  def peak_hours(conn, params) do
    admin = Guardian.Plug.current_resource(conn)

    with {:ok, start_date, end_date} <- parse_date_range(params) do
      peak_hours_data = Admin.get_analytics_peak_hours(start_date, end_date)

      # Log admin action
      Admin.log_audit(admin.id, "view_analytics_peak_hours", "analytics", nil, %{start_date: start_date, end_date: end_date}, get_ip_address(conn))

      conn
      |> put_status(:ok)
      |> json(%{data: peak_hours_data})
    end
  end

  @doc """
  GET /api/admin/analytics/users
  Returns user engagement metrics including DAU, retention, and verification rate.
  Query params: start_date, end_date (ISO8601 format)
  """
  def users(conn, params) do
    admin = Guardian.Plug.current_resource(conn)

    with {:ok, start_date, end_date} <- parse_date_range(params) do
      user_metrics = Admin.get_analytics_user_metrics(start_date, end_date)

      # Log admin action
      Admin.log_audit(admin.id, "view_analytics_users", "analytics", nil, %{start_date: start_date, end_date: end_date}, get_ip_address(conn))

      conn
      |> put_status(:ok)
      |> json(%{data: user_metrics})
    end
  end

  @doc """
  GET /api/admin/analytics/revenue
  Returns revenue metrics including subscription revenue breakdown.
  Query params: start_date, end_date (ISO8601 format)
  """
  def revenue(conn, params) do
    admin = Guardian.Plug.current_resource(conn)

    with {:ok, start_date, end_date} <- parse_date_range(params) do
      revenue_metrics = Admin.get_analytics_revenue(start_date, end_date)

      # Log admin action
      Admin.log_audit(admin.id, "view_analytics_revenue", "analytics", nil, %{start_date: start_date, end_date: end_date}, get_ip_address(conn))

      conn
      |> put_status(:ok)
      |> json(%{data: revenue_metrics})
    end
  end

  @doc """
  POST /api/admin/analytics/export
  Exports analytics data in CSV or PDF format.
  Body params: data_type (trends|peak_hours|heatmap), format (csv|pdf), start_date, end_date
  """
  def export(conn, params) do
    admin = Guardian.Plug.current_resource(conn)
    data_type = Map.get(params, "data_type", "trends")
    format = Map.get(params, "format", "csv")

    with {:ok, start_date, end_date} <- parse_date_range(params) do
      case format do
        "csv" ->
          csv_data = Admin.export_analytics_csv(data_type, start_date, end_date)

          # Log admin action
          Admin.log_audit(admin.id, "export_analytics", "analytics", nil, %{data_type: data_type, format: format, start_date: start_date, end_date: end_date}, get_ip_address(conn))

          conn
          |> put_resp_content_type("text/csv")
          |> put_resp_header("content-disposition", "attachment; filename=\"analytics_#{data_type}_#{Date.to_string(Date.utc_today())}.csv\"")
          |> send_resp(200, csv_data)

        "pdf" ->
          # PDF export not implemented yet - return error
          conn
          |> put_status(:not_implemented)
          |> json(%{error: "PDF export not yet implemented. Please use CSV format."})

        _ ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Invalid format. Supported formats: csv, pdf"})
      end
    end
  end

  # Private helper functions

  defp parse_date_range(params) do
    start_date_str = Map.get(params, "start_date")
    end_date_str = Map.get(params, "end_date")

    # Default to last 30 days if not provided
    default_end = DateTime.utc_now()
    default_start = DateTime.add(default_end, -30, :day)

    start_date = case start_date_str do
      nil -> default_start
      str ->
        case DateTime.from_iso8601(str) do
          {:ok, datetime, _} -> datetime
          _ ->
            # Try parsing as date only
            case Date.from_iso8601(str) do
              {:ok, date} -> DateTime.new!(date, ~T[00:00:00])
              _ -> default_start
            end
        end
    end

    end_date = case end_date_str do
      nil -> default_end
      str ->
        case DateTime.from_iso8601(str) do
          {:ok, datetime, _} -> datetime
          _ ->
            # Try parsing as date only
            case Date.from_iso8601(str) do
              {:ok, date} -> DateTime.new!(date, ~T[23:59:59])
              _ -> default_end
            end
        end
    end

    {:ok, start_date, end_date}
  end

  defp get_ip_address(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> to_string(:inet.ntoa(conn.remote_ip))
    end
  end
end
