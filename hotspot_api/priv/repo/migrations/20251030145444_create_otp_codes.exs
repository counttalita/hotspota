defmodule HotspotApi.Repo.Migrations.CreateOtpCodes do
  use Ecto.Migration

  def change do
    create table(:otp_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :phone_number, :string, null: false
      add :code, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :verified, :boolean, default: false, null: false
      add :attempts, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:otp_codes, [:phone_number, :expires_at])
    create index(:otp_codes, [:phone_number, :verified])
  end
end
