defmodule HotspotApi.Security.IPBlocklist do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ip_blocklist" do
    field :ip_address, :string
    field :reason, :string
    field :blocked_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :is_permanent, :boolean, default: false
  end

  @doc false
  def changeset(ip_blocklist, attrs) do
    ip_blocklist
    |> cast(attrs, [:ip_address, :reason, :expires_at, :is_permanent])
    |> validate_required([:ip_address, :reason])
    |> unique_constraint(:ip_address)
  end
end
