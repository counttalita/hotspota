defmodule HotspotApi.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :phone_number, :string
    field :is_premium, :boolean, default: false
    field :alert_radius, :integer, default: 2000
    field :notification_config, :map, default: %{}
    field :premium_expires_at, :utc_datetime

    has_many :emergency_contacts, HotspotApi.Accounts.EmergencyContact
    has_many :panic_events, HotspotApi.Accounts.PanicEvent

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:phone_number, :is_premium, :alert_radius, :notification_config, :premium_expires_at])
    |> validate_required([:phone_number])
    |> validate_format(:phone_number, ~r/^\+?[1-9]\d{1,14}$/, message: "must be a valid phone number")
    |> validate_number(:alert_radius, greater_than: 0, less_than_or_equal_to: 10000)
    |> unique_constraint(:phone_number)
  end
end
