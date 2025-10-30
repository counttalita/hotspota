defmodule HotspotApi.Accounts.OtpCode do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "otp_codes" do
    field :phone_number, :string
    field :code, :string
    field :expires_at, :utc_datetime
    field :verified, :boolean, default: false
    field :attempts, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(otp_code, attrs) do
    otp_code
    |> cast(attrs, [:phone_number, :code, :expires_at, :verified, :attempts])
    |> validate_required([:phone_number, :code, :expires_at])
    |> validate_format(:phone_number, ~r/^\+?[1-9]\d{1,14}$/)
    |> validate_length(:code, is: 6)
  end
end
