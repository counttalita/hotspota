defmodule HotspotApi.Repo.Migrations.CreateAdminAuditLogs do
  use Ecto.Migration

  def change do
    create table(:admin_audit_logs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :admin_user_id, references(:admin_users, type: :uuid, on_delete: :nilify_all)
      add :action, :string, null: false
      add :resource_type, :string, null: false
      add :resource_id, :uuid
      add :details, :map
      add :ip_address, :string

      timestamps(updated_at: false)
    end

    create index(:admin_audit_logs, [:admin_user_id, :inserted_at])
    create index(:admin_audit_logs, [:resource_type, :resource_id])
    create index(:admin_audit_logs, [:action])
    create index(:admin_audit_logs, [:inserted_at])
  end
end
