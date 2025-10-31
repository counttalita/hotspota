defmodule HotspotApi.Accounts.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @plan_types ~w(monthly annual)
  @statuses ~w(pending active cancelled expired)

  schema "subscriptions" do
    field :plan_type, :string
    field :paystack_subscription_code, :string
    field :paystack_customer_code, :string
    field :paystack_authorization_code, :string
    field :status, :string
    field :amount, :integer
    field :currency, :string, default: "ZAR"
    field :expires_at, :utc_datetime
    field :next_payment_date, :utc_datetime
    field :cancelled_at, :utc_datetime
    field :cancellation_reason, :string

    belongs_to :user, HotspotApi.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :user_id,
      :plan_type,
      :paystack_subscription_code,
      :paystack_customer_code,
      :paystack_authorization_code,
      :status,
      :amount,
      :currency,
      :expires_at,
      :next_payment_date,
      :cancelled_at,
      :cancellation_reason
    ])
    |> validate_required([:user_id, :plan_type, :status, :amount])
    |> validate_inclusion(:plan_type, @plan_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:user_id)
  end

  def plan_amount("monthly"), do: 9900  # R99.00 in kobo
  def plan_amount("annual"), do: 99000  # R990.00 in kobo (2 months free)
  def plan_amount(_), do: 0
end
