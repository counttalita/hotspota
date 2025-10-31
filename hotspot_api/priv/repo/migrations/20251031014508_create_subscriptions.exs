defmodule HotspotApi.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :plan_type, :string, null: false # "monthly" or "annual"
      add :paystack_subscription_code, :string
      add :paystack_customer_code, :string
      add :paystack_authorization_code, :string
      add :status, :string, null: false # "pending", "active", "cancelled", "expired"
      add :amount, :integer, null: false # in kobo (ZAR cents)
      add :currency, :string, default: "ZAR", null: false
      add :expires_at, :utc_datetime
      add :next_payment_date, :utc_datetime
      add :cancelled_at, :utc_datetime
      add :cancellation_reason, :text

      timestamps()
    end

    create index(:subscriptions, [:user_id])
    create index(:subscriptions, [:paystack_subscription_code])
    create index(:subscriptions, [:status])
    create index(:subscriptions, [:expires_at])
  end
end
