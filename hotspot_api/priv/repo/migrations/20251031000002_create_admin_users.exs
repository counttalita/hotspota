defmodule HotspotApi.Repo.Migrations.CreateAdminUsers do
  use Ecto.Migration

  def change do
    create table(:admin_users, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :name, :string, null: false
      add :role, :string, null: false, default: "moderator"
      add :is_active, :boolean, default: true
      add :last_login_at, :utc_datetime

      timestamps()
    end

    create unique_index(:admin_users, [:email])
    create index(:admin_users, [:is_active])
    create index(:admin_users, [:role])

    create constraint(:admin_users, :role_check,
             check: "role IN ('super_admin', 'moderator', 'analyst', 'partner_manager')")
  end
end
