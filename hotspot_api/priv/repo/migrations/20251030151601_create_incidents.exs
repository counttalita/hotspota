defmodule HotspotApi.Repo.Migrations.CreateIncidents do
  use Ecto.Migration

  def up do
    # Enable PostGIS extension if not already enabled
    execute "CREATE EXTENSION IF NOT EXISTS postgis"

    create table(:incidents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :description, :text
      add :photo_url, :string
      add :verification_count, :integer, default: 0, null: false
      add :is_verified, :boolean, default: false, null: false
      add :expires_at, :utc_datetime, null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    # Add PostGIS geometry column for location (Point with SRID 4326 - WGS84)
    execute "SELECT AddGeometryColumn('incidents', 'location', 4326, 'POINT', 2)"
    execute "CREATE INDEX incidents_location_idx ON incidents USING GIST (location)"

    create index(:incidents, [:user_id])
    create index(:incidents, [:type])
    create index(:incidents, [:expires_at])
    create index(:incidents, [:is_verified])
  end

  def down do
    drop table(:incidents)
  end
end
