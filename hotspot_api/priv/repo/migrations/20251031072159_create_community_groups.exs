defmodule HotspotApi.Repo.Migrations.CreateCommunityGroups do
  use Ecto.Migration

  def change do
    # Create community_groups table
    create table(:community_groups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :location_name, :string
      add :center_latitude, :float
      add :center_longitude, :float
      add :radius_meters, :integer, default: 5000
      add :is_public, :boolean, default: true
      add :member_count, :integer, default: 0
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:community_groups, [:created_by_id])
    create index(:community_groups, [:is_public])
    create index(:community_groups, [:center_latitude, :center_longitude])

    # Create group_members table
    create table(:group_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :group_id, references(:community_groups, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, default: "member", null: false
      add :joined_at, :utc_datetime, null: false
      add :notifications_enabled, :boolean, default: true

      timestamps()
    end

    create unique_index(:group_members, [:group_id, :user_id])
    create index(:group_members, [:user_id])
    create index(:group_members, [:group_id])

    # Create group_incidents table to link incidents to groups
    create table(:group_incidents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :group_id, references(:community_groups, type: :binary_id, on_delete: :delete_all), null: false
      add :incident_id, references(:incidents, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:group_incidents, [:group_id, :incident_id])
    create index(:group_incidents, [:incident_id])
  end
end
