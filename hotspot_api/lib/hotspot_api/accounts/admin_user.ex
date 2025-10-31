defmodule HotspotApi.Accounts.AdminUser do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "admin_users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :name, :string
    field :role, :string, default: "moderator"
    field :is_active, :boolean, default: true
    field :last_login_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(admin_user, attrs) do
    admin_user
    |> cast(attrs, [:email, :name, :role, :is_active, :last_login_at])
    |> validate_required([:email, :name, :role])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_inclusion(:role, ["super_admin", "moderator", "analyst", "partner_manager"])
    |> unique_constraint(:email)
  end

  @doc """
  Changeset for creating or updating admin user with password.
  Validates password strength and hashes it using Argon2.
  """
  def registration_changeset(admin_user, attrs) do
    admin_user
    |> changeset(attrs)
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_password_strength()
    |> hash_password()
  end

  defp validate_password_strength(changeset) do
    changeset
    |> validate_length(:password, min: 12, message: "must be at least 12 characters")
    |> validate_format(:password, ~r/[a-z]/, message: "must contain at least one lowercase letter")
    |> validate_format(:password, ~r/[A-Z]/, message: "must contain at least one uppercase letter")
    |> validate_format(:password, ~r/[0-9]/, message: "must contain at least one number")
    |> validate_format(:password, ~r/[!@#$%^&*(),.?":{}|<>]/, message: "must contain at least one special character")
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        changeset
        |> put_change(:password_hash, Argon2.hash_pwd_salt(password))
        |> delete_change(:password)
    end
  end

  @doc """
  Verifies the password against the stored hash.
  """
  def verify_password(%__MODULE__{password_hash: hash}, password) do
    Argon2.verify_pass(password, hash)
  end
end
