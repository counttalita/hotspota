# Hotspot API Deployment Guide

This guide covers deploying the Hotspot Phoenix API to Render with PostgreSQL + PostGIS.

## Prerequisites

- GitHub account with repository access
- Render account (https://render.com)
- Domain name (optional, for custom domain)
- Required API keys:
  - Twilio (Account SID, Auth Token, Phone Number)
  - Firebase Cloud Messaging (Server Key)
  - Paystack (Secret Key, Public Key)
  - AbuseIPDB API Key (optional, for security)

## Step 1: Set Up PostgreSQL Database on Render

1. Log in to Render Dashboard
2. Click "New +" → "PostgreSQL"
3. Configure database:
   - **Name**: `hotspot-db`
   - **Database**: `hotspot_api_prod`
   - **User**: `hotspot_api`
   - **Region**: Choose closest to your users (e.g., Oregon, Frankfurt)
   - **Plan**: Standard or higher (for PostGIS support)
   - **PostgreSQL Version**: 15

4. Click "Create Database"
5. Wait for database to provision
6. Copy the **Internal Database URL** (starts with `postgresql://`)

### Enable PostGIS Extension

After database is created:

1. Go to database dashboard
2. Click "Connect" → "External Connection"
3. Use `psql` to connect:
   ```bash
   psql <EXTERNAL_DATABASE_URL>
   ```

4. Enable PostGIS:
   ```sql
   CREATE EXTENSION IF NOT EXISTS postgis;
   CREATE EXTENSION IF NOT EXISTS postgis_topology;
   \q
   ```

## Step 2: Deploy Phoenix API to Render

### Option A: Using render.yaml (Recommended)

1. Push `render.yaml` to your repository
2. In Render Dashboard, click "New +" → "Blueprint"
3. Connect your GitHub repository
4. Render will detect `render.yaml` and create services automatically
5. Review and approve the services
6. Set environment variables (see Step 3)

### Option B: Manual Setup

1. In Render Dashboard, click "New +" → "Web Service"
2. Connect your GitHub repository
3. Configure service:
   - **Name**: `hotspot-api`
   - **Runtime**: Elixir
   - **Region**: Same as database
   - **Branch**: `main`
   - **Root Directory**: `hotspot_api`
   - **Build Command**: `chmod +x build.sh && ./build.sh`
   - **Start Command**: `_build/prod/rel/hotspot_api/bin/server`
   - **Plan**: Starter or higher
   - **Health Check Path**: `/api/health`

4. Click "Create Web Service"

## Step 3: Configure Environment Variables

In Render Dashboard → Web Service → Environment:

### Required Variables

```bash
# Database (auto-filled if using Blueprint)
DATABASE_URL=<from hotspot-db internal URL>

# Phoenix
SECRET_KEY_BASE=<generate with: mix phx.gen.secret>
GUARDIAN_SECRET_KEY=<generate with: mix phx.gen.secret>
PHX_HOST=hotspot-api.onrender.com
PORT=4000
POOL_SIZE=10
MIX_ENV=prod
PHX_SERVER=true

# Twilio SMS/OTP
TWILIO_ACCOUNT_SID=<your_twilio_account_sid>
TWILIO_AUTH_TOKEN=<your_twilio_auth_token>
TWILIO_FROM_NUMBER=<your_twilio_phone_number>

# Firebase Cloud Messaging
FCM_SERVER_KEY=<your_fcm_server_key>

# Paystack Payments
PAYSTACK_SECRET_KEY=<your_paystack_secret_key>
PAYSTACK_PUBLIC_KEY=<your_paystack_public_key>
PAYSTACK_CALLBACK_URL=https://hotspot-api.onrender.com/api/payment/callback

# Security (optional but recommended)
ABUSEIPDB_API_KEY=<your_abuseipdb_key>
SECURITY_ALERT_EMAIL=<your_email_for_alerts>
BACKUP_ENCRYPTION_KEY=<generate with: mix phx.gen.secret>
```

### Generate Secrets

Run locally to generate secure keys:
```bash
cd hotspot_api
mix phx.gen.secret
```

## Step 4: Run Database Migrations

After first deployment:

1. Go to Render Dashboard → Web Service → Shell
2. Run migrations:
   ```bash
   _build/prod/rel/hotspot_api/bin/hotspot_api eval "HotspotApi.Release.migrate"
   ```

Or create a release task in `lib/hotspot_api/release.ex`:

```elixir
defmodule HotspotApi.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :hotspot_api

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
```

Then run:
```bash
_build/prod/rel/hotspot_api/bin/hotspot_api eval "HotspotApi.Release.migrate"
```

## Step 5: Configure Custom Domain (Optional)

1. In Render Dashboard → Web Service → Settings → Custom Domain
2. Add your domain: `api.hotspot.app`
3. Update DNS records at your domain registrar:
   - Type: `CNAME`
   - Name: `api`
   - Value: `hotspot-api.onrender.com`
4. Wait for DNS propagation (5-30 minutes)
5. Render will automatically provision SSL certificate

Update environment variables:
```bash
PHX_HOST=api.hotspot.app
PAYSTACK_CALLBACK_URL=https://api.hotspot.app/api/payment/callback
```

## Step 6: Set Up CI/CD with GitHub Actions

The repository includes `.github/workflows/deploy.yml` for automated deployments.

### Configure GitHub Secrets

Go to GitHub Repository → Settings → Secrets and variables → Actions:

1. **RENDER_API_KEY**: Get from Render Dashboard → Account Settings → API Keys
2. **RENDER_SERVICE_ID**: Get from Render service URL (e.g., `srv-xxxxx`)
3. **API_URL**: Your API URL (e.g., `https://hotspot-api.onrender.com`)

### Trigger Deployment

Push to `main` branch:
```bash
git add .
git commit -m "Deploy to production"
git push origin main
```

GitHub Actions will:
1. Run tests
2. Check code quality (Credo)
3. Deploy to Render
4. Run health check

## Step 7: Set Up Monitoring

### Option A: Sentry (Recommended)

1. Sign up at https://sentry.io
2. Create new Elixir project
3. Add to `mix.exs`:
   ```elixir
   {:sentry, "~> 10.0"}
   ```

4. Configure in `config/runtime.exs`:
   ```elixir
   config :sentry,
     dsn: System.get_env("SENTRY_DSN"),
     environment_name: :prod,
     enable_source_code_context: true,
     root_source_code_path: File.cwd!(),
     tags: %{
       env: "production"
     }
   ```

5. Add `SENTRY_DSN` to Render environment variables

### Option B: AppSignal

1. Sign up at https://appsignal.com
2. Add to `mix.exs`:
   ```elixir
   {:appsignal, "~> 2.0"}
   {:appsignal_phoenix, "~> 2.0"}
   ```

3. Configure in `config/runtime.exs`:
   ```elixir
   config :appsignal, :config,
     active: true,
     name: "Hotspot API",
     push_api_key: System.get_env("APPSIGNAL_PUSH_API_KEY"),
     env: :prod
   ```

4. Add `APPSIGNAL_PUSH_API_KEY` to Render environment variables

## Step 8: Test Production Deployment

### Health Check
```bash
curl https://hotspot-api.onrender.com/api/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2024-10-31T12:00:00Z",
  "version": "0.1.0",
  "database": "ok",
  "uptime": 3600
}
```

### Test Authentication
```bash
# Send OTP
curl -X POST https://hotspot-api.onrender.com/api/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+1234567890"}'

# Verify OTP
curl -X POST https://hotspot-api.onrender.com/api/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+1234567890", "code": "123456"}'
```

### Test WebSocket Connection
```javascript
// In browser console or Node.js
const socket = new WebSocket('wss://hotspot-api.onrender.com/socket/websocket');
socket.onopen = () => console.log('Connected');
socket.onmessage = (msg) => console.log('Message:', msg.data);
```

## Step 9: Scale for Production

### Horizontal Scaling

1. In Render Dashboard → Web Service → Settings
2. Increase instance count (2+ for high availability)
3. Render automatically load balances across instances

### Database Scaling

1. Upgrade database plan for more resources
2. Enable read replicas for read-heavy workloads
3. Configure connection pooling in `config/runtime.exs`:
   ```elixir
   config :hotspot_api, HotspotApi.Repo,
     pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20")
   ```

### Clustering (Multiple Phoenix Nodes)

Phoenix PubSub automatically syncs across nodes on Render.

To verify clustering:
```elixir
# In Render Shell
_build/prod/rel/hotspot_api/bin/hotspot_api remote

# Check connected nodes
Node.list()
```

## Troubleshooting

### Build Fails

Check build logs in Render Dashboard. Common issues:
- Missing dependencies: Run `mix deps.get`
- Compilation errors: Fix in code and push
- Memory issues: Upgrade to larger plan

### Database Connection Issues

1. Verify `DATABASE_URL` is correct
2. Check database is running
3. Verify PostGIS extension is enabled:
   ```sql
   SELECT PostGIS_version();
   ```

### WebSocket Connection Fails

1. Verify WebSocket endpoint in `endpoint.ex`
2. Check CORS configuration
3. Test with `wscat`:
   ```bash
   npm install -g wscat
   wscat -c wss://hotspot-api.onrender.com/socket/websocket
   ```

### Health Check Fails

1. Check logs: Render Dashboard → Logs
2. Verify database connectivity
3. Check environment variables are set

## Maintenance

### View Logs
```bash
# Real-time logs
Render Dashboard → Web Service → Logs

# Or use Render CLI
render logs -s hotspot-api --tail
```

### Run Migrations
```bash
# In Render Shell
_build/prod/rel/hotspot_api/bin/hotspot_api eval "HotspotApi.Release.migrate"
```

### Rollback Deployment
```bash
# In Render Dashboard
Web Service → Deploys → Select previous deploy → Rollback
```

### Database Backup
```bash
# Render automatically backs up databases daily
# Manual backup:
Render Dashboard → Database → Backups → Create Backup
```

## Security Checklist

- [ ] All environment variables set
- [ ] HTTPS enabled (automatic on Render)
- [ ] CORS configured for production domains
- [ ] Rate limiting enabled
- [ ] Database backups configured
- [ ] Monitoring/alerting set up
- [ ] Security headers configured
- [ ] Secrets rotated regularly (90 days)
- [ ] Dependency scanning enabled (mix_audit)

## Cost Estimation

**Render Pricing (as of 2024):**
- PostgreSQL Standard: $20/month
- Web Service Starter: $7/month
- Web Service Standard: $25/month (recommended for production)

**Total Monthly Cost:**
- Development: ~$27/month (Starter + DB)
- Production: ~$45/month (Standard + DB)
- High Availability: ~$70/month (2x Standard + DB)

## Next Steps

1. Deploy mobile apps to App Store and Google Play
2. Set up admin portal deployment (Vercel/Netlify)
3. Configure CDN for static assets
4. Set up automated database backups
5. Implement log aggregation (Papertrail, Logtail)
6. Set up uptime monitoring (UptimeRobot, Pingdom)

## Support

For issues:
- Render Docs: https://render.com/docs
- Phoenix Deployment: https://hexdocs.pm/phoenix/deployment.html
- Community: https://elixirforum.com
