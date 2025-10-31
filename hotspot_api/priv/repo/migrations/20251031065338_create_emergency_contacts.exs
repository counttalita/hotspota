defmodule HotspotApi.Repo.Migrations.CreateEmergencyContacts do
  use Ecto.Migration

  def change do
    create table(:emergency_contacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :phone_number, :string, null: false
      add :relationship, :string
      add :priority, :integer, default: 1

      timestamps(type: :utc_datetime)
    end

    create index(:emergency_contacts, [:user_id])
    create index(:emergency_contacts, [:user_id, :priority])

    create table(:panic_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :latitude, :float, null: false
      add :longitude, :float, null: false
      add :status, :string, default: "active"
      add :resolved_at, :utc_datetime
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:panic_events, [:user_id])
    create index(:panic_events, [:status])
    create index(:panic_events, [:inserted_at])
  end
end
