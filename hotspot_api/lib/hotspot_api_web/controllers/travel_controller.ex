defmodule HotspotApiWeb.TravelController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Travel

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  Analyze route safety (Premium feature).
  POST /api/travel/analyze-route
  """
  def analyze_route(conn, %{
    "origin" => %{"latitude" => origin_lat, "longitude" => origin_lng},
    "destination" => %{"latitude" => dest_lat, "longitude" => dest_lng}
  } = params) do
    radius = Map.get(params, "radius", 1000)

    result = Travel.analyze_route_safety(
      origin_lat,
      origin_lng,
      dest_lat,
      dest_lng,
      radius
    )

    conn
    |> json(%{
      success: true,
      data: result
    })
  end

  def analyze_route(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      success: false,
      error: "Invalid parameters. Required: origin {latitude, longitude}, destination {latitude, longitude}"
    })
  end
end
