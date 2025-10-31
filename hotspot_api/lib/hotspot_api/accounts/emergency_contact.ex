defmodule HotspotApi.Accounts.EmergencyContact do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "emergency_contacts" do
    field :name, :string
    field :phone_number, :string
    field :relationship, :string
    field :priority, :integer, default: 1

    belongs_to :user, HotspotApi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(emergency_contact, attrs) do
    emergency_contact
    |> cast(attrs, [:name, :phone_number, :relationship, :priority, :user_id])
    |> validate_required([:name, :phone_number, :user_id])
    |> validate_format(:phone_number, ~r/^\+?[1-9]\d{1,14}$/, message: "must be a valid phone number")
    |> validate_number(:priority, greater_than: 0, less_than_or_equal_to: 5)
    |> foreign_key_constraint(:user_id)
  end
end
