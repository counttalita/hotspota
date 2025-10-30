defmodule HotspotApiWeb.IncidentChannel do
  use HotspotApiWeb, :channel

  @impl true
  def join("incidents:" <> geohash, _payload, socket) do
    # Validate geohash format (should be 5-7 characters)
    if valid_geohash?(geohash) do
      {:ok, socket}
    else
      {:error, %{reason: "invalid geohash"}}
    end
  end

  @impl true
  def handle_in("location:update", %{"latitude" => lat, "longitude" => lng}, socket) do
    # Calculate geohash for the user's location (precision 6 = ~1.2km x 0.6km)
    geohash = Geohash.encode(lat, lng, 6)

    # Store user's current geohash in socket assigns
    socket = assign(socket, :current_geohash, geohash)

    # Optionally broadcast user location update to other subscribers
    # (not needed for incident updates, but useful for future features)

    {:reply, {:ok, %{geohash: geohash}}, socket}
  end

  @impl true
  def handle_in("location:update", _payload, socket) do
    {:reply, {:error, %{reason: "missing latitude or longitude"}}, socket}
  end

  @doc """
  Broadcast a new incident to all affected geohash topics.
  This should be called from the Incidents context after creating an incident.
  """
  def broadcast_new_incident(incident) do
    # Get the geohash for the incident location
    %Geo.Point{coordinates: {lng, lat}} = incident.location
    incident_geohash = Geohash.encode(lat, lng, 6)

    # Get neighboring geohashes to cover border cases
    neighbors_map = Geohash.neighbors(incident_geohash)
    neighbor_list = Map.values(neighbors_map)
    all_geohashes = [incident_geohash | neighbor_list]

    # Broadcast to all affected geohash topics
    Enum.each(all_geohashes, fn geohash ->
      HotspotApiWeb.Endpoint.broadcast(
        "incidents:#{geohash}",
        "incident:new",
        %{
          id: incident.id,
          type: incident.type,
          latitude: lat,
          longitude: lng,
          description: incident.description,
          photo_url: incident.photo_url,
          verification_count: incident.verification_count,
          is_verified: incident.is_verified,
          inserted_at: incident.inserted_at
        }
      )
    end)

    :ok
  end

  # Validate geohash format
  defp valid_geohash?(geohash) when is_binary(geohash) do
    String.length(geohash) >= 5 and String.length(geohash) <= 7 and
      String.match?(geohash, ~r/^[0-9b-hjkmnp-z]+$/)
  end

  defp valid_geohash?(_), do: false
end
