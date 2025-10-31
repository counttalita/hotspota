defmodule HotspotApi.Repo.Migrations.AddIdempotencyKeyToIncidents do
  use Ecto.Migration

  def change do
    alter table(:incidents) do
      add :idempotency_key, :string
    end

    create index(:incidents, [:user_id, :idempotency_key], unique: true, where: "idempotency_key IS NOT NULL")
  end
end
