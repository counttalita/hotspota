defmodule HotspotApi.Repo.Migrations.CreateSecurityTables do
  use Ecto.Migration

  def change do
    # IP Blocklist table
    create table(:ip_blocklist, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :ip_address, :string, null: false
      add :reason, :string, null: false
      add :blocked_at, :utc_datetime, default: fragment("NOW()")
      add :expires_at, :utc_datetime
      add :is_permanent, :boolean, default: false
    end

    create unique_index(:ip_blocklist, [:ip_address])
    create index(:ip_blocklist, [:expires_at], where: "expires_at IS NOT NULL")

    # Authentication attempts tracking
    create table(:auth_attempts, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :phone_number, :string
      add :ip_address, :string, null: false
      add :user_agent, :text
      add :success, :boolean, null: false
      add :failure_reason, :string
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    create index(:auth_attempts, [:phone_number, :created_at])
    create index(:auth_attempts, [:ip_address, :created_at])

    # Intrusion detection alerts
    create table(:intrusion_alerts, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :ip_address, :string, null: false
      add :attack_type, :string, null: false
      add :request_path, :string
      add :request_params, :map
      add :severity, :string, null: false
      add :auto_blocked, :boolean, default: false
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    create index(:intrusion_alerts, [:ip_address, :created_at])
    create index(:intrusion_alerts, [:severity, :created_at])
    create index(:intrusion_alerts, [:attack_type])

    # Add constraint for severity levels
    create constraint(:intrusion_alerts, :severity_check,
             check: "severity IN ('low', 'medium', 'high', 'critical')")
  end
end
