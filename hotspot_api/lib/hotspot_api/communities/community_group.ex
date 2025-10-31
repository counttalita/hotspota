defmodule HotspotApi.Communities.CommunityGroup do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "community_groups" do
    field :name, :string
    field :description, :string
    field :location_name, :string
    field :center_latitude, :float
    field :center_longitude, :float
    field :radius_meters, :integer, default: 5000
    field :is_public, :boolean, default: true
    field :member_count, :integer, default: 0

    belongs_to :created_by, HotspotApi.Accounts.User
    has_many :group_members, HotspotApi.Communities.GroupMember, foreign_key: :group_id
    has_many :group_incidents, HotspotApi.Communities.GroupIncident, foreign_key: :group_id

    timestamps()
  end

  @doc false
  def changeset(community_group, attrs) do
    community_group
    |> cast(attrs, [
      :name,
      :description,
      :location_name,
      :center_latitude,
      :center_longitude,
      :radius_meters,
      :is_public,
      :member_count,
      :created_by_id
    ])
    |> validate_required([:name, :created_by_id])
    |> validate_length(:name, min: 3, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_number(:radius_meters, greater_than: 0, less_than_or_equal_to: 50000)
    |> validate_coordinates()
  end

  defp validate_coordinates(changeset) do
    lat = get_field(changeset, :center_latitude)
    lng = get_field(changeset, :center_longitude)

    cond do
      is_nil(lat) and is_nil(lng) ->
        changeset

      is_nil(lat) or is_nil(lng) ->
        changeset
        |> add_error(:center_latitude, "Both latitude and longitude must be provided")
        |> add_error(:center_longitude, "Both latitude and longitude must be provided")

      lat < -90 or lat > 90 ->
        add_error(changeset, :center_latitude, "must be between -90 and 90")

      lng < -180 or lng > 180 ->
        add_error(changeset, :center_longitude, "must be between -180 and 180")

      true ->
        changeset
    end
  end
end
