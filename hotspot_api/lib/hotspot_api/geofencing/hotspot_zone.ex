defmodule HotspotApi.Geofencing.HotspotZone do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "hotspot_zones" do
    field :zone_type, :string
    field :center_location, Geo.PostGIS.Geometry
    field :radius_meters, :integer, default: 1000
    field :incident_count, :integer, default: 0
    field :risk_level, :string
    field :is_active, :boolean, default: true
    field :last_incident_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @valid_types ~w(hijacking mugging accident)
  @valid_risk_levels ~w(low medium high critical)

  @doc false
  def changeset(hotspot_zone, attrs) do
    hotspot_zone
    |> cast(attrs, [:zone_type, :radius_meters, :incident_count, :risk_level, :is_active, :last_incident_at])
    |> cast_center_location(attrs)
    |> validate_required([:zone_type, :center_location, :radius_meters, :incident_count, :risk_level])
    |> validate_inclusion(:zone_type, @valid_types, message: "must be one of: hijacking, mugging, accident")
    |> validate_inclusion(:risk_level, @valid_risk_levels, message: "must be one of: low, medium, high, critical")
    |> validate_number(:radius_meters, greater_than: 0)
    |> validate_number(:incident_count, greater_than_or_equal_to: 0)
  end

  defp cast_center_location(changeset, %{"latitude" => lat, "longitude" => lng}) when is_number(lat) and is_number(lng) do
    point = %Geo.Point{coordinates: {lng, lat}, srid: 4326}
    put_change(changeset, :center_location, point)
  end

  defp cast_center_location(changeset, %{latitude: lat, longitude: lng}) when is_number(lat) and is_number(lng) do
    point = %Geo.Point{coordinates: {lng, lat}, srid: 4326}
    put_change(changeset, :center_location, point)
  end

  defp cast_center_location(changeset, _), do: changeset
end
