defmodule HotspotApi.Accounts.PanicEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "panic_events" do
    field :latitude, :float
    field :longitude, :float
    field :status, :string, default: "active"
    field :resolved_at, :utc_datetime
    field :notes, :string

    belongs_to :user, HotspotApi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(panic_event, attrs) do
    panic_event
    |> cast(attrs, [:latitude, :longitude, :status, :resolved_at, :notes, :user_id])
    |> validate_required([:latitude, :longitude, :user_id])
    |> validate_inclusion(:status, ["active", "resolved", "cancelled"])
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> foreign_key_constraint(:user_id)
  end
end
