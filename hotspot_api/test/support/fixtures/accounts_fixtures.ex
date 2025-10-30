defmodule HotspotApi.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `HotspotApi.Accounts` context.
  """

  @doc """
  Generate a unique user phone_number.
  """
  def unique_user_phone_number, do: "+2712345#{System.unique_integer([:positive])}"

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        phone_number: unique_user_phone_number()
      })
      |> HotspotApi.Accounts.create_user()

    user
  end
end
