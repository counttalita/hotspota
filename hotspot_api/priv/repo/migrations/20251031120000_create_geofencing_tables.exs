defmodule HotspotApi.Repo.Migrations.CreateGeofencingTables do
  use Ecto.Migration

  def change do
    # Create hotspot_zones table
    create table(:hotspot_zones, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :zone_type, :string, null: false
      add :center_location, :geometry, null: false
      add :radius_meters, :integer, null: false, default: 1000
      add :incident_count, :integer, null: false, default: 0
      add :risk_level, :string, null: false
      add :is_active, :boolean, default: true
      add :last_incident_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Create indexes for hotspot_zones
    create index(:hotspot_zones, [:is_active, :zone_type])
    create index(:hotspot_zones, [:risk_level])
    create index(:hotspot_zones, [:center_location], using: "GIST")

    # Create user_zone_tracking table
    create table(:user_zone_tracking, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :zone_id, references(:hotspot_zones, type: :binary_id, on_delete: :delete_all), null: false
      add :entered_at, :utc_datetime, null: false
      add :exited_at, :utc_datetime
      add :notification_sent, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    # Create indexes for user_zone_tracking
    create index(:user_zone_tracking, [:user_id, :exited_at])
    create index(:user_zone_tracking, [:zone_id])
    create index(:user_zone_tracking, [:entered_at])
  end
end
