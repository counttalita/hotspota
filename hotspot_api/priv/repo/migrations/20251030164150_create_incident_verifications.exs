defmodule HotspotApi.Repo.Migrations.CreateIncidentVerifications do
  use Ecto.Migration

  def change do
    create table(:incident_verifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :incident_id, references(:incidents, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:incident_verifications, [:incident_id])
    create index(:incident_verifications, [:user_id])
    create unique_index(:incident_verifications, [:incident_id, :user_id], name: :unique_incident_user_verification)
  end
end
