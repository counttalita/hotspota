# Security Implementation Guide

## Overview

This document outlines the cybersecurity measures implemented in the Hotspot API to protect against common attacks and ensure data security.

## Security Features Implemented

### 1. Security Headers

All API responses include the following security headers:

- `X-Frame-Options: DENY` - Prevents clickjacking attacks
- `X-Content-Type-Options: nosniff` - Prevents MIME type sniffing
- `X-XSS-Protection: 1; mode=block` - Enables browser XSS protection
- `Strict-Transport-Security: max-age=31536000; includeSubDomains` - Enforces HTTPS
- `Content-Security-Policy: default-src 'self'` - Restricts resource loading
- `Referrer-Policy: strict-origin-when-cross-origin` - Controls referrer information
- `Permissions-Policy` - Restricts browser features

### 2. CORS Protection

CORS is configured with a whitelist of allowed origins:
- Production domains (hotspot.app, admin.hotspot.app)
- Development environments (localhost:3000, localhost:5173, localhost:8081)

### 3. Rate Limiting

Multiple rate limiting strategies are implemented:

- **API Rate Limit**: 100 requests per minute per IP address
- **Incident Creation**: 5 incidents per hour per user
- **OTP Requests**: 3 OTP requests per hour per phone number
- **Verification**: 10 verifications per hour per user
- **Authentication**: 5 failed login attempts = 15 minute lockout

### 4. IP Blocklist

Automatic IP blocking for:
- Detected attack patterns (SQL injection, XSS, path traversal)
- Repeated failed authentication attempts
- High abuse scores from threat intelligence feeds

### 5. Threat Intelligence Integration

Integration with AbuseIPDB for real-time threat detection:
- Checks IP addresses against abuse database
- Blocks IPs with abuse confidence score > 75%
- Configurable via `ABUSEIPDB_API_KEY` environment variable

### 6. Intrusion Detection

Automatic detection and blocking of:

- **SQL Injection**: Patterns like `OR 1=1`, `UNION SELECT`, `DROP TABLE`, etc.
- **XSS Attacks**: Patterns like `<script>`, `javascript:`, `onerror=`, etc.
- **Path Traversal**: Patterns like `../`, `%2e%2e`, `/etc/passwd`, etc.

### 7. Authentication Security

- **Secure OTP Generation**: Uses `:crypto.strong_rand_bytes` for cryptographically secure random numbers
- **Password Hashing**: Argon2 algorithm for admin passwords
- **Password Strength**: Minimum 12 characters with uppercase, lowercase, numbers, and special characters
- **JWT Tokens**: Guardian-based authentication with configurable expiration
- **Rate Limiting**: Protection against brute force attacks

### 8. Request/Response Logging

All API requests are logged with:
- Method, path, status code
- Duration in milliseconds
- IP address and user agent
- User ID (if authenticated)
- Timestamp

Security-relevant requests (auth, admin, errors) are stored in the database for forensic analysis.

### 9. CSRF Protection

CSRF tokens are validated for all state-changing operations (POST, PUT, PATCH, DELETE).

### 10. Database Security

- **Parameterized Queries**: All database queries use Ecto parameterized queries to prevent SQL injection
- **Connection Pooling**: Configured with limits to prevent resource exhaustion
  - Pool size: 10 connections
  - Queue target: 50ms
  - Queue interval: 1000ms

### 11. Admin Audit Logging

All admin actions are logged with:
- Admin user ID
- Action performed
- Resource type and ID
- IP address
- Timestamp
- Additional details

### 12. Security Event Logging

Security events are logged for:
- Failed authentication attempts
- Intrusion detection alerts
- IP blocking events
- Threat intelligence blocks
- API errors and suspicious activity

### 13. API Versioning

API endpoints are versioned (`/api/v1/`) to allow security patches without breaking existing clients.

## Environment Variables

### Required for Production

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:5432/database

# Guardian JWT
GUARDIAN_SECRET_KEY=<generate with: mix phx.gen.secret>
SECRET_KEY_BASE=<generate with: mix phx.gen.secret>

# Twilio (for OTP)
TWILIO_ACCOUNT_SID=<your_account_sid>
TWILIO_AUTH_TOKEN=<your_auth_token>
TWILIO_PHONE_NUMBER=<your_twilio_number>

# Firebase Cloud Messaging
FCM_SERVER_KEY=<your_fcm_server_key>
```

### Optional Security Features

```bash
# Threat Intelligence
ABUSEIPDB_API_KEY=<your_api_key>

# Security Alerts
SECURITY_ALERT_EMAIL=security@yourdomain.com

# Email (Swoosh)
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=<your_sendgrid_api_key>
```

## Database Backup Encryption

To encrypt database backups with AES-256:

```bash
# Backup with encryption
pg_dump hotspot_api_prod | openssl enc -aes-256-cbc -salt -pbkdf2 -out backup.sql.enc

# Restore from encrypted backup
openssl enc -aes-256-cbc -d -pbkdf2 -in backup.sql.enc | psql hotspot_api_prod
```

Store encryption keys securely using a secret management service (AWS Secrets Manager, HashiCorp Vault, etc.).

## Secret Rotation Schedule

Rotate the following secrets every 90 days:

1. `GUARDIAN_SECRET_KEY`
2. `SECRET_KEY_BASE`
3. Database passwords
4. API keys (Twilio, FCM, AbuseIPDB)
5. Admin user passwords

## Dependency Vulnerability Scanning

Run vulnerability scans regularly:

```bash
# Install dependencies
mix deps.get

# Run security audit
mix deps.audit

# Check for outdated dependencies
mix hex.outdated
```

Add to CI/CD pipeline:

```yaml
# .github/workflows/security.yml
- name: Security Audit
  run: mix deps.audit
```

## SSL/TLS Configuration

### Let's Encrypt (Recommended)

For Fly.io deployment:

```bash
# Fly.io handles SSL automatically
fly certs add yourdomain.com
fly certs show yourdomain.com
```

### Manual Certificate

```bash
# Generate certificate
certbot certonly --standalone -d api.hotspot.app

# Configure in endpoint
config :hotspot_api, HotspotApiWeb.Endpoint,
  https: [
    port: 443,
    cipher_suite: :strong,
    keyfile: "/etc/letsencrypt/live/api.hotspot.app/privkey.pem",
    certfile: "/etc/letsencrypt/live/api.hotspot.app/fullchain.pem"
  ]
```

## Firewall Rules (Fly.io)

Configure in `fly.toml`:

```toml
[[services]]
  internal_port = 4000
  protocol = "tcp"

  [[services.ports]]
    handlers = ["http"]
    port = 80
    force_https = true

  [[services.ports]]
    handlers = ["tls", "http"]
    port = 443

  [[services.tcp_checks]]
    interval = "15s"
    timeout = "2s"
    grace_period = "5s"
```

## DDoS Protection

### Cloudflare Setup

1. Add your domain to Cloudflare
2. Enable "Under Attack Mode" if needed
3. Configure rate limiting rules
4. Enable Bot Fight Mode

### Application-Level Protection

- Rate limiting per IP (100 req/min)
- Connection pooling limits
- Request timeout configuration
- Automatic IP blocking for repeated attacks

## Monitoring and Alerting

### Sentry Integration

```elixir
# config/prod.exs
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: :prod,
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  tags: %{
    env: "production"
  }
```

### Security Alerts

High and critical severity intrusion alerts automatically send email notifications to the security team.

## Security Checklist

- [ ] All secrets stored in environment variables (never in code)
- [ ] HTTPS enforced in production
- [ ] Database backups encrypted
- [ ] Rate limiting configured
- [ ] IP blocklist enabled
- [ ] Intrusion detection active
- [ ] Security headers configured
- [ ] CORS whitelist configured
- [ ] Admin passwords meet strength requirements
- [ ] Dependency vulnerability scanning in CI/CD
- [ ] Security monitoring (Sentry) configured
- [ ] Secret rotation schedule established
- [ ] Firewall rules configured
- [ ] DDoS protection enabled (Cloudflare)
- [ ] Request/response logging enabled
- [ ] Admin audit logging enabled

## Incident Response

If a security incident is detected:

1. Check intrusion alerts: `SELECT * FROM intrusion_alerts ORDER BY created_at DESC LIMIT 100;`
2. Review blocked IPs: `SELECT * FROM ip_blocklist WHERE blocked_at > NOW() - INTERVAL '24 hours';`
3. Check security events: `SELECT * FROM security_events WHERE severity IN ('high', 'critical') ORDER BY inserted_at DESC;`
4. Review admin audit logs: `SELECT * FROM admin_audit_logs ORDER BY inserted_at DESC LIMIT 100;`
5. Analyze request logs for patterns
6. Block additional IPs if needed: `HotspotApi.Security.block_ip("1.2.3.4", "Manual block: incident response", permanent: true)`
7. Rotate compromised secrets immediately
8. Notify affected users if data breach occurred

## Contact

For security issues, contact: security@hotspot.app
