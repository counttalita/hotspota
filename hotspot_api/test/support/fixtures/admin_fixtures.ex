defmodule HotspotApi.AdminFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `HotspotApi.Admin` context.
  """

  alias HotspotApi.Admin

  @doc """
  Generate a unique admin email.
  """
  def unique_admin_email, do: "admin#{System.unique_integer([:positive])}@example.com"

  @doc """
  Generate an admin user.
  """
  def admin_user_fixture(attrs \\ %{}) do
    {:ok, admin_user} =
      attrs
      |> Enum.into(%{
        email: unique_admin_email(),
        password: "SecurePassword123!",
        name: "Test Admin",
        role: "moderator",
        is_active: true
      })
      |> Admin.create_admin()

    # Remove password from returned struct for security
    Map.delete(admin_user, :password)
  end
end
