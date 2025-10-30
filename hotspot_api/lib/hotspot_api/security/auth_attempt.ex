defmodule HotspotApi.Security.AuthAttempt do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "auth_attempts" do
    field :phone_number, :string
    field :ip_address, :string
    field :user_agent, :string
    field :success, :boolean
    field :failure_reason, :string
    field :created_at, :utc_datetime
  end

  @doc false
  def changeset(auth_attempt, attrs) do
    auth_attempt
    |> cast(attrs, [:phone_number, :ip_address, :user_agent, :success, :failure_reason])
    |> validate_required([:ip_address, :success])
  end
end
