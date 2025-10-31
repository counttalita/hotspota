defmodule HotspotApi.GeofencingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `HotspotApi.Geofencing` context.
  """

  alias HotspotApi.Repo
  alias HotspotApi.Geofencing.HotspotZone

  @doc """
  Generate a hotspot zone.
  """
  def hotspot_zone_fixture(attrs \\ %{}) do
    {:ok, zone} =
      attrs
      |> Enum.into(%{
        latitude: -26.2041,
        longitude: 28.0473,
        radius_meters: 1000,
        zone_type: "hijacking",
        risk_level: "medium",
        incident_count: 5,
        is_active: true,
        last_incident_at: DateTime.utc_now()
      })
      |> then(fn attrs ->
        %HotspotZone{}
        |> HotspotZone.changeset(attrs)
        |> Repo.insert()
      end)

    zone
  end
end
