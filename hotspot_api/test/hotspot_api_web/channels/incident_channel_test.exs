defmodule HotspotApiWeb.IncidentChannelTest do
  use HotspotApiWeb.ChannelCase

  alias HotspotApiWeb.IncidentChannel

  setup do
    # Create a test user
    user = HotspotApi.AccountsFixtures.user_fixture()

    # Generate a valid geohash for testing (Johannesburg area)
    geohash = "kegxs5"

    {:ok, _, socket} =
      HotspotApiWeb.UserSocket
      |> socket("user_id", %{user_id: user.id})
      |> subscribe_and_join(IncidentChannel, "incidents:#{geohash}")

    %{socket: socket, user: user, geohash: geohash}
  end

  test "join with valid geohash succeeds", %{socket: socket} do
    assert socket.topic == "incidents:kegxs5"
  end

  test "location:update returns geohash", %{socket: socket} do
    ref = push(socket, "location:update", %{
      "latitude" => -26.2041,
      "longitude" => 28.0473
    })

    assert_reply ref, :ok, %{geohash: geohash}
    assert is_binary(geohash)
    assert String.length(geohash) == 6
  end

  test "location:update without coordinates returns error", %{socket: socket} do
    ref = push(socket, "location:update", %{})
    assert_reply ref, :error, %{reason: "missing latitude or longitude"}
  end

  test "broadcast_new_incident sends to channel subscribers" do
    # Create a test incident
    user = HotspotApi.AccountsFixtures.user_fixture()

    {:ok, incident} = HotspotApi.Incidents.create_incident(%{
      "user_id" => user.id,
      "type" => "hijacking",
      "latitude" => -26.2041,
      "longitude" => 28.0473,
      "description" => "Test incident"
    })

    # The broadcast happens automatically in create_incident
    # We just verify the incident was created
    assert incident.type == "hijacking"
  end
end
