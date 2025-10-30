# Hotspot Backend API

Backend REST API and WebSocket server for the Hotspot community safety reporting application.

## 🏗️ Architecture

- **Framework**: Phoenix 1.8 (Elixir)
- **Database**: PostgreSQL 16 with PostGIS extension
- **Cache**: Redis 7.x
- **Real-time**: Phoenix Channels (WebSocket)
- **Authentication**: Guardian (JWT tokens)
- **OTP**: Twilio Verify API
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **Image Storage**: Cloudinary
- **Background Jobs**: Oban

## 📋 Features

### Core Services

- **Authentication Service** - Phone number + OTP verification, JWT token management
- **Incident Service** - CRUD operations for incident reports with geospatial queries
- **Geofencing Service** - Automatic hotspot zone creation and entry/exit detection
- **Notification Service** - Push notifications via FCM with radius-based targeting
- **Verification Service** - Community upvoting and incident verification
- **Analytics Service** - Hotspot statistics, time patterns, and trend analysis
- **Monetization Service** - Partner sponsorships and enterprise API access

### Real-Time Features

- WebSocket connections via Phoenix Channels
- Live incident updates broadcast to nearby users
- Hotspot zone entry/exit alerts
- Geohash-based room subscriptions for efficient broadcasting

## 🚀 Getting Started

### Prerequisites

- Elixir 1.15+ and Erlang/OTP 26+
- PostgreSQL 16 with PostGIS extension
- Redis 7.x
- Twilio account (for OTP)
- Firebase project (for push notifications)
- Cloudinary account (for image uploads)

### Installation

1. **Install dependencies**
   ```bash
   mix setup
   ```

2. **Configure environment variables**
   ```bash
   cp .env.example .env
   ```

   Edit `.env` with your credentials:
   ```bash
   DATABASE_URL=postgres://user:pass@localhost/hotspot_dev
   REDIS_URL=redis://localhost:6379
   SECRET_KEY_BASE=your_secret_key
   TWILIO_ACCOUNT_SID=your_twilio_sid
   TWILIO_AUTH_TOKEN=your_twilio_token
   TWILIO_VERIFY_SERVICE_SID=your_verify_service_sid
   FCM_SERVER_KEY=your_fcm_server_key
   CLOUDINARY_URL=cloudinary://key:secret@cloud_name
   ```

3. **Set up the database**
   ```bash
   mix ecto.setup
   ```

   This will:
   - Create the database
   - Enable PostGIS extension
   - Run migrations
   - Seed initial data

4. **Start the Phoenix server**
   ```bash
   mix phx.server
   ```

   Or start it inside IEx:
   ```bash
   iex -S mix phx.server
   ```

The API will be available at [`http://localhost:4000`](http://localhost:4000)

## 📡 API Endpoints

### Authentication
```
POST   /api/auth/send-otp          # Send OTP to phone number
POST   /api/auth/verify-otp        # Verify OTP and get JWT token
POST   /api/auth/refresh-token     # Refresh JWT token
GET    /api/auth/me                # Get current user
```

### Incidents
```
POST   /api/incidents              # Create incident report
GET    /api/incidents/nearby       # Get incidents near location
GET    /api/incidents/:id          # Get incident details
PUT    /api/incidents/:id          # Update incident
DELETE /api/incidents/:id          # Delete incident (admin only)
GET    /api/incidents/heatmap      # Get heatmap data
```

### Geofencing
```
GET    /api/geofence/zones         # Get hotspot zones in bounds
GET    /api/geofence/zones/:id     # Get zone details
POST   /api/geofence/check-location # Check if location is in hotspot
GET    /api/geofence/user-zones    # Get zones user is currently in
```

### Verification
```
POST   /api/incidents/:id/verify   # Upvote/verify incident
GET    /api/incidents/:id/verifications # Get verification count
```

### Notifications
```
POST   /api/notifications/register-token  # Register FCM token
PUT    /api/notifications/preferences     # Update notification settings
GET    /api/notifications/preferences     # Get notification settings
```

### Analytics
```
GET    /api/analytics/hotspots     # Get top hotspot areas
GET    /api/analytics/time-patterns # Get peak incident hours
GET    /api/analytics/trends       # Get weekly trends
GET    /api/analytics/heatmap      # Get heatmap density data
```

### Monetization (Admin/Partner)
```
POST   /api/monetization/partners          # Create partner (admin)
GET    /api/monetization/partners          # List partners
PUT    /api/monetization/partners/:id      # Update partner
GET    /api/monetization/sponsored-alerts  # Get sponsored alerts
POST   /api/monetization/track-impression  # Track alert impression
POST   /api/monetization/enterprise/register # Register enterprise client
GET    /api/monetization/enterprise/dashboard # Enterprise dashboard
```

## 🔌 WebSocket Channels

### Incident Channel
```elixir
# Join channel
channel "incidents:*", HotspotApiWeb.IncidentChannel

# Client → Server events
incident:subscribe    # Subscribe to region updates
incident:unsubscribe  # Unsubscribe from updates
location:update       # Update user location

# Server → Client events
incident:new          # New incident in region
incident:updated      # Incident verification changed
incident:expired      # Incident removed
```

### Geofence Channel
```elixir
# Join channel
channel "geofence:*", HotspotApiWeb.GeofenceChannel

# Client → Server events
zone:subscribe        # Subscribe to zone updates
location:update       # Update user location for zone detection

# Server → Client events
zone:entered          # User entered hotspot zone
zone:exited           # User exited hotspot zone
zone:created          # New zone created
zone:dissolved        # Zone dissolved
```

## 🗄️ Database Schema

### Key Tables

**users** - User accounts with phone authentication
```sql
id, phone_number, is_premium, premium_expires_at, alert_radius, 
notification_config, created_at, updated_at
```

**incidents** - Reported safety incidents
```sql
id, user_id, type, location (geography), description, photo_url,
verification_count, is_verified, expires_at, created_at, updated_at
```

**hotspot_zones** - Geofenced danger zones
```sql
id, zone_type, center_location (geography), radius, incident_count,
risk_level, is_active, created_at, updated_at, last_incident_at
```

**incident_verifications** - Community upvotes
```sql
id, incident_id, user_id, created_at
```

**fcm_tokens** - Push notification tokens
```sql
id, user_id, token, platform, created_at, updated_at
```

**partners** - Sponsored alert partners
```sql
id, name, logo_url, partner_type, service_regions, is_active,
monthly_fee, contract_start, contract_end, created_at
```

**enterprise_clients** - B2B API clients
```sql
id, company_name, api_key, subscription_tier, monthly_fee,
max_api_calls, service_regions, white_label_config, is_active, created_at
```

## 🔧 Background Jobs (Oban)

### Scheduled Jobs

**HotspotZoneUpdater** - Runs every 10 minutes
- Identifies incident clusters using PostGIS ST_ClusterDBSCAN
- Creates new hotspot zones (5+ incidents in 1km radius)
- Dissolves zones with < 3 incidents in past 7 days
- Calculates risk levels

**IncidentExpiration** - Runs every hour
- Removes unverified incidents after 48 hours
- Cleans up expired incident data

**NotificationQueue** - Processes in real-time
- Sends FCM push notifications
- Handles retry logic with exponential backoff

## 🧪 Testing

```bash
# Run all tests
mix test

# Run specific test file
mix test test/hotspot_api/incidents_test.exs

# Run tests with coverage
mix test --cover

# Run failed tests only
mix test --failed

# Run tests in watch mode
mix test.watch
```

### Test Structure
```
test/
├── hotspot_api/              # Context tests
│   ├── auth_test.exs
│   ├── incidents_test.exs
│   ├── geofencing_test.exs
│   └── analytics_test.exs
├── hotspot_api_web/          # Controller/Channel tests
│   ├── controllers/
│   └── channels/
└── support/                  # Test helpers
```

## 🚢 Deployment

### Production Setup

1. **Build release**
   ```bash
   MIX_ENV=prod mix release
   ```

2. **Run migrations**
   ```bash
   _build/prod/rel/hotspot_api/bin/hotspot_api eval "HotspotApi.Release.migrate"
   ```

3. **Start server**
   ```bash
   _build/prod/rel/hotspot_api/bin/hotspot_api start
   ```

### Environment Variables (Production)

```bash
SECRET_KEY_BASE=<generate with mix phx.gen.secret>
DATABASE_URL=<production postgres url>
REDIS_URL=<production redis url>
PHX_HOST=api.hotspot.app
PORT=4000
POOL_SIZE=10
```

### Deployment Platforms

**Recommended**: Render or Fly.io

**Render**:
```bash
# render.yaml
services:
  - type: web
    name: hotspot-api
    env: elixir
    buildCommand: mix deps.get --only prod && mix compile
    startCommand: mix phx.server
```

**Fly.io**:
```bash
fly launch
fly deploy
```

## 📊 Monitoring

### Health Check
```bash
GET /api/health
```

### Metrics
- Phoenix LiveDashboard: `/dashboard` (dev only)
- Telemetry metrics via AppSignal or New Relic
- Database query performance tracking
- WebSocket connection monitoring

## 🔒 Security

- JWT tokens with 7-day expiration
- OTP rate limiting (3 attempts per hour per phone)
- API rate limiting (100 requests/minute per user)
- Report creation rate limiting (1 per minute per user)
- SQL injection prevention via Ecto parameterized queries
- XSS prevention in descriptions
- File upload validation (size, type)
- CORS configuration for mobile apps only

## 🐛 Debugging

```bash
# Start with debugger
iex -S mix phx.server

# Check logs
tail -f log/dev.log

# Database console
mix ecto.psql

# Check running processes
:observer.start()
```

## 📚 Additional Resources

- [Phoenix Framework Docs](https://hexdocs.pm/phoenix)
- [Ecto Query Guide](https://hexdocs.pm/ecto/Ecto.Query.html)
- [PostGIS Documentation](https://postgis.net/docs/)
- [Oban Background Jobs](https://hexdocs.pm/oban)
- [Guardian Authentication](https://hexdocs.pm/guardian)

## 🤝 Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) in the root directory.

## 📄 License

MIT License - see [LICENSE](../LICENSE) file for details.
