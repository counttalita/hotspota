defmodule HotspotApi.Repo.Migrations.CreateModerationTables do
  use Ecto.Migration

  def change do
    # Flagged content table
    create table(:flagged_content, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :incident_id, references(:incidents, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :content_type, :string, null: false
      add :flag_reason, :string, null: false
      add :moderation_score, :float
      add :status, :string, default: "pending", null: false
      add :reviewed_by, :binary_id
      add :reviewed_at, :utc_datetime

      timestamps()
    end

    create index(:flagged_content, [:status, :inserted_at])
    create index(:flagged_content, [:user_id])
    create index(:flagged_content, [:incident_id])

    # Image hashes table for duplicate detection
    create table(:image_hashes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :hash, :string, null: false
      add :incident_id, references(:incidents, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:image_hashes, [:hash])
    create index(:image_hashes, [:incident_id])

    # Security events table
    create table(:security_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_type, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :ip_address, :string
      add :user_agent, :text
      add :details, :map
      add :severity, :string, null: false

      timestamps()
    end

    create index(:security_events, [:user_id, :inserted_at])
    create index(:security_events, [:event_type, :inserted_at])
    create index(:security_events, [:severity, :inserted_at])
  end
end
