defmodule HotspotApi.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :phone_number, :string, null: false
      add :is_premium, :boolean, default: false, null: false
      add :alert_radius, :integer, default: 2000, null: false
      add :notification_config, :map, default: %{}
      add :premium_expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:phone_number])
  end
end
