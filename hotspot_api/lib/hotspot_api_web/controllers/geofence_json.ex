defmodule HotspotApiWeb.GeofenceJSON do
  alias HotspotApi.Geofencing.HotspotZone

  @doc """
  Renders a list of hotspot zones.
  """
  def index(%{zones: zones}) do
    %{data: for(zone <- zones, do: data(zone))}
  end

  @doc """
  Renders a single hotspot zone.
  """
  def show(%{zone: zone}) do
    %{data: data(zone)}
  end

  defp data(%HotspotZone{} = zone) do
    %Geo.Point{coordinates: {lng, lat}} = zone.center_location

    %{
      id: zone.id,
      zone_type: zone.zone_type,
      center: %{
        latitude: lat,
        longitude: lng
      },
      radius_meters: zone.radius_meters,
      incident_count: zone.incident_count,
      risk_level: zone.risk_level,
      is_active: zone.is_active,
      last_incident_at: zone.last_incident_at,
      inserted_at: zone.inserted_at,
      updated_at: zone.updated_at
    }
  end
end
