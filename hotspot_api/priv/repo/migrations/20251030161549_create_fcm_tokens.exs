defmodule HotspotApi.Repo.Migrations.CreateFcmTokens do
  use Ecto.Migration

  def change do
    create table(:fcm_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :string, null: false
      add :platform, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:fcm_tokens, [:user_id])
    create unique_index(:fcm_tokens, [:user_id, :token])
  end
end
