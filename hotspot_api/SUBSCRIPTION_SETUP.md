# Subscription Setup Guide

This guide explains how to set up and test the premium subscription feature with Paystack.

## Prerequisites

1. Create a Paystack account at https://paystack.com
2. Get your API keys from the Paystack dashboard

## Configuration

### 1. Environment Variables

Add the following to your `.env` file:

```bash
# Paystack Configuration
PAYSTACK_SECRET_KEY=sk_test_your_test_secret_key  # Use sk_live_ for production
PAYSTACK_PUBLIC_KEY=pk_test_your_test_public_key  # Use pk_live_ for production
PAYSTACK_CALLBACK_URL=http://localhost:3000/payment/callback
```

### 2. Test Mode vs Production

- **Test Mode**: Use `sk_test_` and `pk_test_` keys for development
- **Production**: Use `sk_live_` and `pk_live_` keys for production

## Subscription Plans

### Monthly Premium - R99.00/month
- Extended alert radius (up to 10km)
- City-wide analytics
- Travel Mode with route safety
- Background notifications
- SOS with trusted contacts
- Advance hotspot zone warnings

### Annual Premium - R990.00/year (17% off)
- All monthly features
- 2 months free
- Priority support

## API Endpoints

### Get Available Plans
```bash
GET /api/subscriptions/plans
```

### Initialize Subscription
```bash
POST /api/subscriptions/initialize
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "plan_type": "monthly"  // or "annual"
}
```

Response:
```json
{
  "success": true,
  "data": {
    "subscription_id": "uuid",
    "authorization_url": "https://checkout.paystack.com/...",
    "reference": "SUB_uuid_timestamp"
  }
}
```

### Get Subscription Status
```bash
GET /api/subscriptions/status
Authorization: Bearer <jwt_token>
```

### Cancel Subscription
```bash
POST /api/subscriptions/cancel
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "reason": "Optional cancellation reason"
}
```

## Webhook Setup

### 1. Configure Webhook URL in Paystack Dashboard

Go to Settings > Webhooks and add:
```
https://your-domain.com/api/subscriptions/webhook
```

### 2. Webhook Events Handled

- `charge.success` - Activates subscription after successful payment
- `subscription.disable` - Deactivates subscription when cancelled

### 3. Webhook Security

The webhook endpoint verifies the signature using HMAC SHA512:
```elixir
signature = :crypto.mac(:hmac, :sha512, secret_key, payload)
```

## Testing

### 1. Test Payment Flow

1. Initialize a subscription via API
2. Open the `authorization_url` in a browser
3. Use Paystack test cards:
   - Success: `4084084084084081`
   - Decline: `5060666666666666666`
4. Complete the payment
5. Webhook will be triggered to activate subscription

### 2. Test Webhook Locally

Use ngrok to expose your local server:
```bash
ngrok http 4000
```

Update Paystack webhook URL to:
```
https://your-ngrok-url.ngrok.io/api/subscriptions/webhook
```

### 3. Manual Webhook Testing

```bash
curl -X POST http://localhost:4000/api/subscriptions/webhook \
  -H "Content-Type: application/json" \
  -H "x-paystack-signature: <computed_signature>" \
  -d '{
    "event": "charge.success",
    "data": {
      "reference": "SUB_uuid_timestamp",
      "subscription_code": "SUB_xxx",
      "customer": {
        "customer_code": "CUS_xxx"
      }
    }
  }'
```

## Premium Features

### 1. Extended Alert Radius

Premium users can set alert radius up to 10km (vs 2km for free users).

### 2. Travel Mode

Analyze route safety between two locations:
```bash
POST /api/travel/analyze-route
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "origin": {
    "latitude": -26.2041,
    "longitude": 28.0473
  },
  "destination": {
    "latitude": -26.1076,
    "longitude": 28.0567
  },
  "radius": 1000
}
```

### 3. Premium Middleware

Protect endpoints with premium requirement:
```elixir
pipeline :premium_required do
  plug HotspotApiWeb.Plugs.PremiumRequired
end

scope "/api/v1", HotspotApiWeb do
  pipe_through [:api_v1, :auth, :premium_required]
  
  post "/travel/analyze-route", TravelController, :analyze_route
end
```

## Troubleshooting

### Webhook Not Received

1. Check Paystack webhook logs in dashboard
2. Verify webhook URL is accessible
3. Check server logs for errors
4. Ensure signature verification is working

### Payment Not Activating Subscription

1. Check webhook was received
2. Verify reference format matches `SUB_<uuid>_<timestamp>`
3. Check subscription record in database
4. Verify user premium status was updated

### Premium Features Not Working

1. Check user `is_premium` field is true
2. Verify `premium_expires_at` is in the future
3. Check JWT token includes updated user data
4. Verify premium middleware is applied to route

## Production Checklist

- [ ] Replace test keys with live keys
- [ ] Update callback URL to production domain
- [ ] Configure webhook URL in Paystack dashboard
- [ ] Test payment flow end-to-end
- [ ] Set up monitoring for failed payments
- [ ] Configure email notifications for subscription events
- [ ] Test subscription cancellation flow
- [ ] Verify premium features are properly gated
- [ ] Set up backup for subscription data
- [ ] Configure SSL/TLS for webhook endpoint

## Support

For Paystack API documentation, visit:
https://paystack.com/docs/api/

For issues with this implementation, check:
- Server logs: `tail -f log/dev.log`
- Database: `psql hotspot_api_dev -c "SELECT * FROM subscriptions;"`
- Webhook logs in Paystack dashboard
