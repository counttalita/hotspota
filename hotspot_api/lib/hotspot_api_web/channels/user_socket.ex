defmodule HotspotApiWeb.UserSocket do
  use Phoenix.Socket

  # Channels
  channel "incidents:*", HotspotApiWeb.IncidentChannel
  channel "geofence:*", HotspotApiWeb.GeofenceChannel
  channel "community:*", HotspotApiWeb.CommunityChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    # Verify Guardian JWT token
    case HotspotApi.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        user_id = claims["sub"]
        {:ok, assign(socket, :user_id, user_id)}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info) do
    :error
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
