defmodule HotspotApiWeb.AnalyticsController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Analytics

  # Plug to ensure user is premium for city-wide analytics
  plug :ensure_premium when action in [:hotspots]

  @doc """
  GET /api/analytics/hotspots
  Returns top 5 hotspot areas with highest incident counts.
  Requires premium subscription for access.
  """
  def hotspots(conn, _params) do
    hotspots = Analytics.get_top_hotspots()

    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      data: hotspots
    })
  end

  @doc """
  GET /api/analytics/time-patterns
  Returns peak hours analysis for each incident type.
  Available to all authenticated users.
  """
  def time_patterns(conn, _params) do
    patterns = Analytics.get_time_patterns()

    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      data: patterns
    })
  end

  @doc """
  GET /api/analytics/trends
  Returns weekly incident trends.
  Accepts optional 'weeks' query parameter (default: 4).
  Available to all authenticated users.
  """
  def trends(conn, params) do
    weeks = Map.get(params, "weeks", "4") |> String.to_integer()
    # Limit to reasonable range
    weeks = min(max(weeks, 1), 52)

    trends = Analytics.get_weekly_trends(weeks)

    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      data: trends
    })
  end

  @doc """
  GET /api/analytics/summary
  Returns overall analytics summary.
  Available to all authenticated users.
  """
  def summary(conn, _params) do
    summary = Analytics.get_analytics_summary()

    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      data: summary
    })
  end

  # Private plug to ensure user has premium subscription
  defp ensure_premium(conn, _opts) do
    user = Guardian.Plug.current_resource(conn)

    if user && user.is_premium do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{
        success: false,
        error: "Premium subscription required",
        message: "This feature requires a premium subscription. Upgrade to access city-wide analytics."
      })
      |> halt()
    end
  end
end
