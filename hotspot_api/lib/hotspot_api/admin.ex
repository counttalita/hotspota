defmodule HotspotApi.Admin do
  @moduledoc """
  The Admin context for managing admin users and authentication.
  """

  import Ecto.Query, warn: false
  alias HotspotApi.Repo
  alias HotspotApi.Admin.AdminUser

  @doc """
  Gets a single admin user by email.
  """
  def get_admin_by_email(email) when is_binary(email) do
    Repo.get_by(AdminUser, email: email)
  end

  @doc """
  Gets a single admin user by id.
  """
  def get_admin!(id), do: Repo.get!(AdminUser, id)

  @doc """
  Authenticates an admin user with email and password.
  """
  def authenticate_admin(email, password) when is_binary(email) and is_binary(password) do
    admin = get_admin_by_email(email)

    cond do
      admin && admin.is_active && Argon2.verify_pass(password, admin.password_hash) ->
        update_last_login(admin)
        {:ok, admin}

      admin ->
        Argon2.no_user_verify()
        {:error, :invalid_credentials}

      true ->
        Argon2.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  @doc """
  Creates an admin user.
  """
  def create_admin(attrs \\ %{}) do
    %AdminUser{}
    |> AdminUser.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an admin user.
  """
  def update_admin(%AdminUser{} = admin, attrs) do
    admin
    |> AdminUser.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates the last login timestamp for an admin user.
  """
  def update_last_login(%AdminUser{} = admin) do
    admin
    |> Ecto.Changeset.change(last_login_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  @doc """
  Lists all admin users.
  """
  def list_admins do
    Repo.all(AdminUser)
  end
end
