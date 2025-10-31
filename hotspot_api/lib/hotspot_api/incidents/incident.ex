defmodule HotspotApi.Incidents.Incident do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "incidents" do
    field :type, :string
    field :description, :string
    field :photo_url, :string
    field :verification_count, :integer, default: 0
    field :is_verified, :boolean, default: false
    field :expires_at, :utc_datetime
    field :location, Geo.PostGIS.Geometry
    field :idempotency_key, :string

    belongs_to :user, HotspotApi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @valid_types ~w(hijacking mugging accident)

  @doc false
  def changeset(incident, attrs) do
    incident
    |> cast(attrs, [:type, :description, :photo_url, :verification_count, :is_verified, :expires_at, :user_id, :idempotency_key])
    |> cast_location(attrs)
    |> validate_required([:type, :location, :expires_at, :user_id])
    |> validate_inclusion(:type, @valid_types, message: "must be one of: hijacking, mugging, accident")
    |> validate_length(:description, max: 280)
    |> unique_constraint([:user_id, :idempotency_key], name: :incidents_user_id_idempotency_key_index)
    |> foreign_key_constraint(:user_id)
  end

  defp cast_location(changeset, %{"latitude" => lat, "longitude" => lng}) when is_number(lat) and is_number(lng) do
    point = %Geo.Point{coordinates: {lng, lat}, srid: 4326}
    put_change(changeset, :location, point)
  end

  defp cast_location(changeset, %{latitude: lat, longitude: lng}) when is_number(lat) and is_number(lng) do
    point = %Geo.Point{coordinates: {lng, lat}, srid: 4326}
    put_change(changeset, :location, point)
  end

  defp cast_location(changeset, _), do: changeset
end
