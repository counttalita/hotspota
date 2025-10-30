defmodule HotspotApi.Security.SecurityEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "security_events" do
    field :event_type, :string
    field :ip_address, :string
    field :user_agent, :string
    field :details, :map
    field :severity, :string

    belongs_to :user, HotspotApi.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(security_event, attrs) do
    security_event
    |> cast(attrs, [:event_type, :user_id, :ip_address, :user_agent, :details, :severity])
    |> validate_required([:event_type, :severity])
    |> validate_inclusion(:severity, ["low", "medium", "high", "critical"])
    |> foreign_key_constraint(:user_id)
  end
end
