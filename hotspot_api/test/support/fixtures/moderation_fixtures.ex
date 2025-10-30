defmodule HotspotApi.ModerationFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `HotspotApi.Moderation` context.
  """

  alias HotspotApi.Moderation

  def flagged_content_fixture(attrs \\ %{}) do
    {:ok, flagged_content} =
      attrs
      |> Enum.into(%{
        content_type: "text",
        flag_reason: "profanity",
        status: "pending"
      })
      |> Moderation.create_flagged_content()

    flagged_content
  end

  def image_hash_fixture(attrs \\ %{}) do
    {:ok, image_hash} =
      attrs
      |> Enum.into(%{
        hash: "test_hash_#{System.unique_integer([:positive])}"
      })
      |> Moderation.create_image_hash()

    image_hash
  end
end
