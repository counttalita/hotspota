defmodule HotspotApi.ModerationTest do
  use HotspotApi.DataCase

  alias HotspotApi.Moderation
  alias HotspotApi.Moderation.TextFilter

  import HotspotApi.AccountsFixtures
  import HotspotApi.IncidentsFixtures
  import HotspotApi.ModerationFixtures

  describe "text validation" do
    test "validates text length" do
      # Too short
      assert {:error, :text_too_short, _} = Moderation.validate_text("short", min_length: 10)

      # Too long
      long_text = String.duplicate("a", 501)
      assert {:error, :text_too_long, _} = Moderation.validate_text(long_text, max_length: 500)

      # Valid length
      assert {:ok, _} = Moderation.validate_text("This is a valid description text")
    end

    test "filters profanity" do
      text = "This is a fucking test"
      {:ok, filtered} = TextFilter.filter_profanity(text)
      assert filtered =~ "******"
      refute filtered =~ "fucking"
    end

    test "detects hate speech" do
      text = "I hate all people"
      assert {:error, :hate_speech_detected, _} = TextFilter.detect_hate_speech(text)

      clean_text = "This is a normal description"
      assert {:ok, ^clean_text} = TextFilter.detect_hate_speech(clean_text)
    end

    test "escapes HTML" do
      text = "<script>alert('xss')</script>"
      {:ok, escaped} = TextFilter.escape_html(text)
      refute escaped =~ "<script>"
      assert escaped =~ "&lt;script&gt;"
    end

    test "contains_profanity? check" do
      assert TextFilter.contains_profanity?("This is fucking bad")
      refute TextFilter.contains_profanity?("This is a clean text")
    end
  end

  describe "image validation" do
    test "validates file type" do
      # Create a temporary test file
      file_path = Path.join(System.tmp_dir!(), "test_image.jpg")
      File.write!(file_path, "fake image content")

      # Valid type
      assert {:ok, _hash} = Moderation.validate_image(file_path, "image/jpeg")

      # Invalid type
      assert {:error, :invalid_file_type, _} = Moderation.validate_image(file_path, "application/pdf")

      # Cleanup
      File.rm(file_path)
    end

    test "generates image hash" do
      file_path = Path.join(System.tmp_dir!(), "test_image.jpg")
      File.write!(file_path, "fake image content")

      {:ok, hash} = Moderation.generate_image_hash(file_path)
      assert is_binary(hash)
      assert String.length(hash) == 32  # MD5 hash length

      File.rm(file_path)
    end
  end

  describe "flagged content" do
    setup do
      user = user_fixture()
      incident = incident_fixture(%{user_id: user.id})
      %{user: user, incident: incident}
    end

    test "creates flagged content", %{user: user, incident: incident} do
      attrs = %{
        incident_id: incident.id,
        user_id: user.id,
        content_type: "text",
        flag_reason: "profanity"
      }

      assert {:ok, flagged} = Moderation.create_flagged_content(attrs)
      assert flagged.content_type == "text"
      assert flagged.flag_reason == "profanity"
      assert flagged.status == "pending"
    end

    test "lists flagged content with filters", %{user: user, incident: incident} do
      flagged_content_fixture(%{user_id: user.id, incident_id: incident.id, status: "pending"})
      flagged_content_fixture(%{user_id: user.id, incident_id: incident.id, status: "approved"})

      all_flagged = Moderation.list_flagged_content()
      assert length(all_flagged) == 2

      pending_only = Moderation.list_flagged_content(%{status: "pending"})
      assert length(pending_only) == 1
    end

    test "checks repeat offender", %{user: user, incident: incident} do
      # Create 3 rejected flagged content items
      for _ <- 1..3 do
        flagged_content_fixture(%{user_id: user.id, incident_id: incident.id, status: "rejected"})
      end

      assert {:warning, :repeat_offender, 3} = Moderation.check_repeat_offender(user.id)
    end
  end
end
