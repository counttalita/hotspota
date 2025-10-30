# Phoenix Channels - Real-time Incident Updates

## Overview

The Hotspot API uses Phoenix Channels to provide real-time incident updates to mobile clients. This implementation uses geohash-based topic subscription to efficiently broadcast incidents only to users in affected geographical areas.

## Architecture

### Geohash-Based Topics

- Each channel topic is based on a geohash (precision 6 = ~1.2km x 0.6km)
- Users subscribe to the geohash of their current location
- When an incident is created, it's broadcast to the incident's geohash and all 8 neighboring geohashes
- This ensures users near geohash boundaries still receive relevant updates

### Components

1. **UserSocket** (`user_socket.ex`)
   - Handles WebSocket connections
   - Authenticates users via JWT token
   - Routes to appropriate channels

2. **IncidentChannel** (`incident_channel.ex`)
   - Manages incident-related real-time updates
   - Handles location updates from clients
   - Broadcasts new incidents to affected geohashes

## Client Usage

### Connecting to WebSocket

```javascript
import { Socket } from 'phoenix';

const socket = new Socket('ws://localhost:4000/socket', {
  params: { token: 'YOUR_JWT_TOKEN' }
});

socket.connect();
```

### Joining Incident Channel

```javascript
// Calculate geohash for user's location (precision 6)
const geohash = geohash.encode(latitude, longitude, 6);

// Join channel
const channel = socket.channel(`incidents:${geohash}`, {});

channel.join()
  .receive('ok', () => console.log('Joined successfully'))
  .receive('error', (resp) => console.error('Failed to join', resp));
```

### Listening for New Incidents

```javascript
channel.on('incident:new', (incident) => {
  console.log('New incident:', incident);
  // Update UI with new incident
});
```

### Updating Location

```javascript
channel.push('location:update', {
  latitude: -26.2041,
  longitude: 28.0473
})
  .receive('ok', (resp) => {
    console.log('Location updated, geohash:', resp.geohash);
    // If geohash changed, rejoin channel with new geohash
  });
```

## Server-Side Broadcasting

When a new incident is created, it's automatically broadcast to all affected geohashes:

```elixir
# In Incidents context
def create_incident(attrs) do
  result = %Incident{}
    |> Incident.changeset(attrs)
    |> Repo.insert()

  case result do
    {:ok, incident} ->
      HotspotApiWeb.IncidentChannel.broadcast_new_incident(incident)
      {:ok, incident}
    error ->
      error
  end
end
```

## Testing

Run channel tests:

```bash
mix test test/hotspot_api_web/channels/
```

## Configuration

WebSocket endpoint is configured in `endpoint.ex`:

```elixir
socket "/socket", HotspotApiWeb.UserSocket,
  websocket: true,
  longpoll: false
```

## Security

- All connections require valid JWT authentication
- Users can only join channels (no unauthorized broadcasting)
- Geohash validation prevents invalid topic subscriptions
