defmodule HotspotApi.Notifications.FcmToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "fcm_tokens" do
    field :token, :string
    field :platform, :string

    belongs_to :user, HotspotApi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @valid_platforms ~w(ios android)

  @doc false
  def changeset(fcm_token, attrs) do
    fcm_token
    |> cast(attrs, [:token, :platform, :user_id])
    |> validate_required([:token, :platform, :user_id])
    |> validate_inclusion(:platform, @valid_platforms, message: "must be either ios or android")
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :token])
  end
end
