defmodule HotspotApiWeb.GeofenceController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Geofencing

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  GET /api/geofence/zones
  Returns all active hotspot zones, optionally filtered by bounds.
  """
  def index(conn, _params) do
    zones = Geofencing.list_active_zones()

    render(conn, :index, zones: zones)
  end

  @doc """
  GET /api/geofence/zones/:id
  Returns a specific hotspot zone by ID.
  """
  def show(conn, %{"id" => id}) do
    zone = Geofencing.get_zone!(id)

    render(conn, :show, zone: zone)
  end

  @doc """
  POST /api/geofence/check-location
  Check if a location is within any active hotspot zones.
  """
  def check_location(conn, %{"latitude" => lat, "longitude" => lng}) do
    zones = Geofencing.check_location(lat, lng)

    render(conn, :index, zones: zones)
  end

  def check_location(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing latitude or longitude"})
  end

  @doc """
  GET /api/geofence/user-zones
  Get zones that the authenticated user is currently in.
  """
  def user_zones(conn, _params) do
    user_id = conn.assigns[:current_user].id
    zones = Geofencing.get_user_current_zones(user_id)

    render(conn, :index, zones: zones)
  end
end
