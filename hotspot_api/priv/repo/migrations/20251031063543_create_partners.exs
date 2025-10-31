defmodule HotspotApi.Repo.Migrations.CreatePartners do
  use Ecto.Migration

  def change do
    create table(:partners, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :logo_url, :string
      add :partner_type, :string, null: false
      add :service_regions, :map
      add :is_active, :boolean, default: true, null: false
      add :monthly_fee, :decimal, precision: 10, scale: 2
      add :contract_start, :date
      add :contract_end, :date
      add :contact_email, :string
      add :contact_phone, :string

      timestamps()
    end

    create index(:partners, [:is_active])
    create index(:partners, [:partner_type])

    create table(:sponsored_alerts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :partner_id, references(:partners, type: :binary_id, on_delete: :delete_all), null: false
      add :incident_id, references(:incidents, type: :binary_id, on_delete: :delete_all), null: false
      add :impression_count, :integer, default: 0, null: false
      add :click_count, :integer, default: 0, null: false

      timestamps()
    end

    create index(:sponsored_alerts, [:partner_id])
    create index(:sponsored_alerts, [:incident_id])
    create unique_index(:sponsored_alerts, [:partner_id, :incident_id])
  end
end
