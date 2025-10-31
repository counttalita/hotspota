# Hotspot Admin Portal - Deployment Guide

## Prerequisites

- Render account (https://render.com)
- GitHub repository with admin portal code
- Backend API deployed and accessible

## Deployment Steps

### 1. Build Production Bundle Locally (Testing)

Before deploying, test the production build locally:

```bash
cd hotspot_admin
npm install
npm run build
npm run preview
```

This will:
- Compile TypeScript
- Build optimized production bundle
- Preview the production build locally at http://localhost:4173

### 2. Deploy to Render

#### Option A: Using Render Dashboard (Recommended)

1. **Create New Static Site**
   - Go to https://dashboard.render.com
   - Click "New +" → "Static Site"
   - Connect your GitHub repository
   - Select the `hotspot_admin` directory as the root

2. **Configure Build Settings**
   - **Name**: `hotspot-admin`
   - **Branch**: `main` (or your production branch)
   - **Root Directory**: `hotspot_admin`
   - **Build Command**: `npm install && npm run build`
   - **Publish Directory**: `dist`

3. **Configure Environment Variables**
   - Add environment variable:
     - Key: `VITE_API_URL`
     - Value: `https://hotspot-api.onrender.com` (your backend API URL)

4. **Advanced Settings**
   - **Auto-Deploy**: Enable (deploys on every push to main branch)
   - **Pull Request Previews**: Enable (optional, for testing)

5. **Deploy**
   - Click "Create Static Site"
   - Render will automatically build and deploy your site
   - Your site will be available at: `https://hotspot-admin.onrender.com`

#### Option B: Using render.yaml (Infrastructure as Code)

1. Ensure `render.yaml` is in the `hotspot_admin` directory
2. In Render Dashboard:
   - Go to "Blueprint" → "New Blueprint Instance"
   - Connect your repository
   - Select the `hotspot_admin/render.yaml` file
   - Review and approve the configuration
   - Click "Apply"

### 3. Configure Custom Domain (Optional)

1. In Render Dashboard, go to your static site
2. Click "Settings" → "Custom Domain"
3. Add your domain: `admin.hotspot.app`
4. Follow DNS configuration instructions:
   - Add CNAME record: `admin` → `hotspot-admin.onrender.com`
5. SSL certificate will be automatically provisioned by Render

### 4. Configure Backend CORS

Update the backend to allow requests from the admin portal:

**File**: `hotspot_api/lib/hotspot_api_web/endpoint.ex`

```elixir
cors_origins =
  case Application.get_env(:hotspot_api, :env, :dev) do
    :prod ->
      [
        "https://hotspot.app",
        "https://www.hotspot.app",
        "https://admin.hotspot.app",
        "https://hotspot-admin.onrender.com",  # Add this line
        ~r/^https:\/\/.*\.hotspot\.app$/
      ]
    _ ->
      [
        "http://localhost:8081",
        "exp://localhost:8081",
        "http://localhost:3000",
        "http://localhost:5173"  # Vite dev server
      ]
  end
```

Redeploy the backend after making this change.

### 5. Implement Rate Limiting for Admin Endpoints

Add rate limiting to protect admin endpoints from abuse:

**File**: `hotspot_api/lib/hotspot_api_web/plugs/rate_limiter.ex`

```elixir
defmodule HotspotApiWeb.Plugs.RateLimiter do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, opts) do
    limit = Keyword.get(opts, :limit, 100)
    window_ms = Keyword.get(opts, :window_ms, 60_000)
    
    identifier = get_identifier(conn)
    key = "rate_limit:#{identifier}"
    
    case check_rate_limit(key, limit, window_ms) do
      {:ok, _count} ->
        conn
      {:error, :rate_limit_exceeded} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{error: "Rate limit exceeded. Please try again later."})
        |> halt()
    end
  end

  defp get_identifier(conn) do
    # Use IP address or authenticated user ID
    case Guardian.Plug.current_resource(conn) do
      nil -> get_ip_address(conn)
      user -> "user:#{user.id}"
    end
  end

  defp get_ip_address(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> to_string(:inet.ntoa(conn.remote_ip))
    end
  end

  defp check_rate_limit(key, limit, window_ms) do
    # Simple in-memory rate limiting using ETS
    # For production, consider using Redis or Hammer library
    table = :rate_limiter_table
    
    case :ets.lookup(table, key) do
      [] ->
        :ets.insert(table, {key, 1, System.monotonic_time(:millisecond)})
        {:ok, 1}
      [{^key, count, timestamp}] ->
        now = System.monotonic_time(:millisecond)
        if now - timestamp > window_ms do
          :ets.insert(table, {key, 1, now})
          {:ok, 1}
        else
          if count < limit do
            :ets.update_counter(table, key, {2, 1})
            {:ok, count + 1}
          else
            {:error, :rate_limit_exceeded}
          end
        end
    end
  end
end
```

**Apply rate limiting to admin routes**:

**File**: `hotspot_api/lib/hotspot_api_web/router.ex`

```elixir
pipeline :admin_api do
  plug :accepts, ["json"]
  plug HotspotApiWeb.Plugs.RateLimiter, limit: 100, window_ms: 60_000
  plug HotspotApiWeb.Plugs.AdminAuth
end

scope "/api/admin", HotspotApiWeb.Admin do
  pipe_through :admin_api
  
  # All admin routes here
end
```

### 6. Test Production Deployment

After deployment, test all admin features:

1. **Authentication**
   - [ ] Login with admin credentials
   - [ ] Logout functionality
   - [ ] Session persistence
   - [ ] Token refresh

2. **Dashboard**
   - [ ] Stats cards display correctly
   - [ ] Real-time activity feed updates
   - [ ] Charts render properly

3. **Incident Management**
   - [ ] List incidents with pagination
   - [ ] Search and filter functionality
   - [ ] Moderate incidents (approve/flag/delete)
   - [ ] Bulk actions work
   - [ ] Photo preview modal

4. **User Management**
   - [ ] List users with search
   - [ ] View user details
   - [ ] Suspend/ban users
   - [ ] Grant/revoke premium
   - [ ] Send notifications

5. **Zone Management**
   - [ ] List zones
   - [ ] Create manual zones
   - [ ] Edit zone properties
   - [ ] Dissolve zones
   - [ ] View zone incidents

6. **Analytics**
   - [ ] Trend charts display
   - [ ] Heatmap renders
   - [ ] Export functionality
   - [ ] Date range filtering

7. **Partner Management**
   - [ ] List partners
   - [ ] Add/edit partners
   - [ ] View statistics
   - [ ] Toggle active status

### 7. Create Admin User Accounts

Use the backend console or API to create admin accounts:

```bash
# SSH into your Render backend service
# Or use Render Shell

# In IEx console:
alias HotspotApi.Accounts

# Create super admin
{:ok, admin} = Accounts.create_admin_user(%{
  email: "admin@hotspot.app",
  password: "SecurePassword123!",
  name: "Super Admin",
  role: "super_admin"
})

# Create moderator
{:ok, moderator} = Accounts.create_admin_user(%{
  email: "moderator@hotspot.app",
  password: "SecurePassword123!",
  name: "Content Moderator",
  role: "moderator"
})

# Create analyst
{:ok, analyst} = Accounts.create_admin_user(%{
  email: "analyst@hotspot.app",
  password: "SecurePassword123!",
  name: "Data Analyst",
  role: "analyst"
})
```

## Environment Variables Reference

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `VITE_API_URL` | Backend API URL | `https://hotspot-api.onrender.com` |

### Optional Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_VERSION` | Node.js version | `20.11.0` |

## Monitoring and Maintenance

### Performance Monitoring

1. **Render Metrics**
   - Monitor build times
   - Check bandwidth usage
   - Review error logs

2. **Browser Performance**
   - Use Lighthouse for performance audits
   - Monitor Core Web Vitals
   - Check bundle size (should be < 500KB gzipped)

### Security Best Practices

1. **Regular Updates**
   - Update dependencies monthly: `npm update`
   - Check for security vulnerabilities: `npm audit`
   - Update Node.js version as needed

2. **Access Control**
   - Limit admin user creation
   - Use strong passwords (min 12 characters)
   - Enable 2FA for admin accounts (future enhancement)
   - Regularly audit admin access logs

3. **HTTPS Only**
   - Ensure all traffic uses HTTPS
   - Enable HSTS headers (already configured)
   - Verify SSL certificate is valid

### Troubleshooting

#### Build Fails

```bash
# Clear cache and rebuild
rm -rf node_modules dist
npm install
npm run build
```

#### API Connection Issues

1. Check `VITE_API_URL` is correct
2. Verify CORS is configured on backend
3. Check network tab in browser DevTools
4. Verify backend is running and accessible

#### Blank Page After Deployment

1. Check browser console for errors
2. Verify all environment variables are set
3. Check that routing is configured correctly in render.yaml
4. Ensure `index.html` is in the dist folder

## Rollback Procedure

If deployment fails or issues arise:

1. **Render Dashboard**
   - Go to your static site
   - Click "Deploys" tab
   - Find the last working deployment
   - Click "Redeploy"

2. **Git Revert**
   ```bash
   git revert HEAD
   git push origin main
   ```
   Render will automatically deploy the reverted version

## Cost Estimation

**Render Static Site Pricing**:
- Free tier: 100GB bandwidth/month
- Starter: $7/month - 100GB bandwidth
- Standard: $25/month - 1TB bandwidth

**Recommended**: Start with free tier, upgrade as traffic grows.

## Support

For deployment issues:
- Render Documentation: https://render.com/docs/static-sites
- Render Community: https://community.render.com
- GitHub Issues: Create an issue in your repository
