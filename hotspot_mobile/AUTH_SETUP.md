# Hotspot Mobile - Authentication Setup

## Overview
This document describes the phone authentication flow implementation for the Hotspot mobile app.

## Features Implemented
- ✅ Phone number input screen with validation
- ✅ OTP verification screen with 6-digit input
- ✅ JWT token storage using AsyncStorage
- ✅ Loading states and error handling
- ✅ Automatic navigation after successful authentication
- ✅ Token persistence across app restarts

## Dependencies Installed
```json
{
  "@react-navigation/native": "^6.1.9",
  "@react-navigation/stack": "^6.3.20",
  "react-native-screens": "~4.4.0",
  "react-native-safe-area-context": "4.14.0",
  "@react-native-async-storage/async-storage": "2.1.0",
  "axios": "^1.6.2"
}
```

## File Structure
```
hotspot_mobile/
├── src/
│   ├── screens/
│   │   ├── PhoneAuthScreen.js       # Phone number input
│   │   ├── OTPVerificationScreen.js # OTP verification
│   │   └── MainScreen.js            # Main app screen (placeholder)
│   └── services/
│       └── authService.js           # Authentication API service
├── App.js                           # Navigation setup
└── package.json
```

## Configuration

### API URL
Update the API URL in `src/services/authService.js`:
```javascript
const API_URL = 'http://localhost:4000/api'; // Change for production
```

For iOS simulator, use: `http://localhost:4000/api`
For Android emulator, use: `http://10.0.2.2:4000/api`
For physical device, use your computer's IP: `http://192.168.x.x:4000/api`

## Running the App

1. Start the backend server:
```bash
cd hotspot_api
mix phx.server
```

2. Start the mobile app:
```bash
cd hotspot_mobile
npm start
```

3. Press `i` for iOS simulator or `a` for Android emulator

## Testing the Authentication Flow

### 1. Phone Number Input
- Enter a valid phone number (e.g., +27123456789)
- Validation checks for E.164 format
- Rate limiting: Max 3 OTP requests per hour

### 2. OTP Verification
- Enter the 6-digit code sent via SMS
- In development (without Twilio configured), check backend logs for OTP
- Auto-submits when all 6 digits are entered
- Can resend OTP if not received

### 3. Successful Authentication
- JWT token stored in AsyncStorage
- User data cached locally
- Navigates to main screen
- Token persists across app restarts

## Error Handling

### Phone Number Screen
- Empty phone number
- Invalid phone number format
- Rate limit exceeded (429)
- Network errors

### OTP Verification Screen
- Invalid OTP code
- Expired OTP code
- Too many verification attempts
- Network errors

## Security Features
- JWT tokens with 90-day expiration
- Automatic token refresh on API calls
- Secure storage using AsyncStorage
- Rate limiting on OTP requests
- OTP expiration (10 minutes)

## Backend Integration
The mobile app integrates with these backend endpoints:

- `POST /api/auth/send-otp` - Send OTP to phone number
- `POST /api/auth/verify-otp` - Verify OTP and get JWT token
- `GET /api/auth/me` - Get current user info (requires auth)

## Next Steps
- Implement map view (Task 3)
- Add incident reporting (Task 4)
- Implement real-time updates (Task 5)
- Add push notifications (Task 7)
