defmodule HotspotApi.Accounts.AdminAuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "admin_audit_logs" do
    field :action, :string
    field :resource_type, :string
    field :resource_id, :binary_id
    field :details, :map
    field :ip_address, :string

    belongs_to :admin_user, HotspotApi.Accounts.AdminUser

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:admin_user_id, :action, :resource_type, :resource_id, :details, :ip_address])
    |> validate_required([:action, :resource_type])
    |> foreign_key_constraint(:admin_user_id)
  end
end
