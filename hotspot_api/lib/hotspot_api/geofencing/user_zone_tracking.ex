defmodule HotspotApi.Geofencing.UserZoneTracking do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_zone_tracking" do
    field :entered_at, :utc_datetime
    field :exited_at, :utc_datetime
    field :notification_sent, :boolean, default: false

    belongs_to :user, HotspotApi.Accounts.User
    belongs_to :zone, HotspotApi.Geofencing.HotspotZone

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_zone_tracking, attrs) do
    user_zone_tracking
    |> cast(attrs, [:user_id, :zone_id, :entered_at, :exited_at, :notification_sent])
    |> validate_required([:user_id, :zone_id, :entered_at])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:zone_id)
  end
end
