# Hotspot Mobile App Deployment Guide

This guide covers building and deploying the Hotspot React Native mobile app to iOS App Store and Google Play Store.

## Prerequisites

- macOS (for iOS builds)
- Xcode 14+ with Command Line Tools
- Apple Developer Account ($99/year)
- Google Play Developer Account ($25 one-time)
- EAS (Expo Application Services) account
- Node.js 18+ and npm/yarn

## Step 1: Configure App for Production

### Update app.json

```json
{
  "expo": {
    "name": "Hotspot",
    "slug": "hotspot",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/icon.png",
    "userInterfaceStyle": "light",
    "splash": {
      "image": "./assets/splash-icon.png",
      "resizeMode": "contain",
      "backgroundColor": "#ffffff"
    },
    "assetBundlePatterns": [
      "**/*"
    ],
    "ios": {
      "supportsTablet": true,
      "bundleIdentifier": "com.hotspot.app",
      "buildNumber": "1",
      "infoPlist": {
        "NSLocationWhenInUseUsageDescription": "Hotspot needs your location to show nearby safety incidents and alert you when entering danger zones.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Hotspot needs background location access to alert you when entering hotspot zones even when the app is closed.",
        "NSCameraUsageDescription": "Hotspot needs camera access to let you capture photos of incidents.",
        "NSPhotoLibraryUsageDescription": "Hotspot needs photo library access to let you attach photos to incident reports."
      },
      "config": {
        "googleMapsApiKey": "YOUR_IOS_GOOGLE_MAPS_KEY"
      }
    },
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/adaptive-icon.png",
        "backgroundColor": "#ffffff"
      },
      "package": "com.hotspot.app",
      "versionCode": 1,
      "permissions": [
        "ACCESS_COARSE_LOCATION",
        "ACCESS_FINE_LOCATION",
        "ACCESS_BACKGROUND_LOCATION",
        "CAMERA",
        "READ_EXTERNAL_STORAGE",
        "WRITE_EXTERNAL_STORAGE"
      ],
      "config": {
        "googleMaps": {
          "apiKey": "YOUR_ANDROID_GOOGLE_MAPS_KEY"
        }
      }
    },
    "web": {
      "favicon": "./assets/favicon.png"
    },
    "plugins": [
      "expo-location",
      "expo-camera",
      "expo-notifications"
    ],
    "extra": {
      "eas": {
        "projectId": "YOUR_EAS_PROJECT_ID"
      }
    }
  }
}
```

### Update Environment Variables

Create `.env.production`:
```bash
API_URL=https://api.hotspot.app
WS_URL=wss://api.hotspot.app/socket
GOOGLE_MAPS_API_KEY=your_google_maps_key
SENTRY_DSN=your_sentry_dsn
```

## Step 2: Set Up EAS Build

### Install EAS CLI

```bash
npm install -g eas-cli
```

### Login to EAS

```bash
eas login
```

### Initialize EAS

```bash
cd hotspot_mobile
eas build:configure
```

This creates `eas.json`:

```json
{
  "cli": {
    "version": ">= 5.0.0"
  },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal",
      "ios": {
        "simulator": true
      }
    },
    "preview": {
      "distribution": "internal",
      "ios": {
        "simulator": false
      }
    },
    "production": {
      "env": {
        "API_URL": "https://api.hotspot.app",
        "WS_URL": "wss://api.hotspot.app/socket"
      }
    }
  },
  "submit": {
    "production": {}
  }
}
```

## Step 3: Build for iOS

### Prerequisites

1. Apple Developer Account
2. App Store Connect app created
3. Certificates and provisioning profiles (EAS handles this)

### Create App in App Store Connect

1. Go to https://appstoreconnect.apple.com
2. Click "My Apps" → "+" → "New App"
3. Fill in details:
   - **Platform**: iOS
   - **Name**: Hotspot
   - **Primary Language**: English
   - **Bundle ID**: com.hotspot.app
   - **SKU**: hotspot-ios
   - **User Access**: Full Access

### Build iOS App

```bash
eas build --platform ios --profile production
```

EAS will:
1. Create/update certificates and provisioning profiles
2. Build the app on EAS servers
3. Provide download link for `.ipa` file

### Submit to App Store

```bash
eas submit --platform ios --profile production
```

Or manually:
1. Download `.ipa` from EAS build
2. Open Xcode → Window → Organizer
3. Drag `.ipa` to Organizer
4. Click "Distribute App" → "App Store Connect"
5. Follow prompts to upload

### Configure App Store Listing

In App Store Connect:

1. **App Information**
   - Category: Navigation
   - Subcategory: Safety

2. **Pricing and Availability**
   - Price: Free
   - Availability: All countries

3. **App Privacy**
   - Location: Used for showing nearby incidents
   - Photos: Used for incident reporting
   - User Content: Incident reports

4. **Screenshots** (Required sizes)
   - 6.7" (iPhone 14 Pro Max): 1290 x 2796
   - 6.5" (iPhone 11 Pro Max): 1242 x 2688
   - 5.5" (iPhone 8 Plus): 1242 x 2208

5. **App Preview Video** (Optional but recommended)

6. **Description**
```
Stay safe with real-time community safety alerts. Hotspot shows you nearby incidents (hijackings, muggings, accidents) reported by other users, helping you avoid dangerous areas.

Features:
• Real-time incident map with color-coded markers
• Push notifications for nearby threats
• Quick incident reporting with one tap
• Heat zones showing high-risk areas
• Community verification system
• Offline support for low-connectivity areas
• Premium features: Extended alert radius, route safety analysis, SOS button

Join thousands of users staying safer together.
```

7. **Keywords**
```
safety, crime, alert, map, incident, security, emergency, community
```

8. **Support URL**: https://hotspot.app/support
9. **Marketing URL**: https://hotspot.app

### Submit for Review

1. Add screenshots and description
2. Set age rating (12+ for crime content)
3. Click "Submit for Review"
4. Review typically takes 24-48 hours

## Step 4: Build for Android

### Prerequisites

1. Google Play Developer Account
2. App created in Google Play Console
3. Keystore for signing (EAS handles this)

### Create App in Google Play Console

1. Go to https://play.google.com/console
2. Click "Create app"
3. Fill in details:
   - **App name**: Hotspot
   - **Default language**: English
   - **App or game**: App
   - **Free or paid**: Free

### Build Android App

```bash
eas build --platform android --profile production
```

EAS will:
1. Create/manage keystore
2. Build signed `.aab` (Android App Bundle)
3. Provide download link

### Submit to Google Play

```bash
eas submit --platform android --profile production
```

Or manually:
1. Download `.aab` from EAS build
2. Go to Google Play Console → Your App → Production
3. Click "Create new release"
4. Upload `.aab` file
5. Add release notes
6. Click "Review release" → "Start rollout to Production"

### Configure Play Store Listing

In Google Play Console:

1. **Store Listing**
   - **Short description** (80 chars):
   ```
   Real-time safety alerts. See nearby incidents, avoid danger zones.
   ```

   - **Full description** (4000 chars):
   ```
   Stay safe with Hotspot - the community-driven safety app that keeps you informed about nearby incidents in real-time.

   🗺️ REAL-TIME INCIDENT MAP
   See hijackings, muggings, and accidents reported by other users on an interactive map. Color-coded markers help you quickly identify threat types.

   🔔 INSTANT ALERTS
   Get push notifications when incidents are reported near you. Configure your alert radius and choose which incident types to monitor.

   ⚡ QUICK REPORTING
   Report incidents with one tap. Auto-capture location, add optional photo and description. Help keep your community safe.

   🔥 HEAT ZONES
   Visualize high-risk areas with heat zones showing incident density. Avoid dangerous neighborhoods before you enter them.

   ✅ COMMUNITY VERIFICATION
   Upvote incidents to verify authenticity. Verified reports are marked with badges for trustworthiness.

   📱 OFFLINE SUPPORT
   Queue reports when offline. Cached map tiles work without internet. Syncs automatically when connection restored.

   💎 PREMIUM FEATURES
   • Extended alert radius (up to 10km)
   • Route safety analysis before travel
   • City-wide analytics and trends
   • SOS button with trusted contacts
   • Background notifications
   • Advance hotspot zone warnings

   🔒 PRIVACY & SECURITY
   • No personal information required
   • Phone number authentication only
   • Encrypted data transmission
   • Content moderation for quality

   Join thousands of users staying safer together. Download Hotspot now.
   ```

   - **App icon**: 512 x 512 PNG
   - **Feature graphic**: 1024 x 500 PNG
   - **Screenshots**: At least 2, up to 8 (phone and tablet)
   - **Phone screenshots**: 16:9 or 9:16 ratio
   - **Tablet screenshots**: 16:9 or 9:16 ratio

2. **Content Rating**
   - Complete questionnaire
   - Expected rating: PEGI 12 / ESRB Teen (crime content)

3. **Target Audience**
   - Age: 18+
   - Target audience: Adults

4. **App Category**
   - Category: Maps & Navigation
   - Tags: Safety, Security, Community

5. **Contact Details**
   - Email: support@hotspot.app
   - Phone: Optional
   - Website: https://hotspot.app

6. **Privacy Policy**
   - URL: https://hotspot.app/privacy

### Submit for Review

1. Complete all required sections
2. Click "Submit for review"
3. Review typically takes 1-3 days

## Step 5: Set Up Push Notifications

### iOS (APNs)

1. In Apple Developer Portal:
   - Certificates, Identifiers & Profiles
   - Keys → "+" → Apple Push Notifications service (APNs)
   - Download `.p8` key file
   - Note Key ID and Team ID

2. Upload to Firebase:
   - Firebase Console → Project Settings → Cloud Messaging
   - iOS app configuration → APNs Authentication Key
   - Upload `.p8` file
   - Enter Key ID and Team ID

### Android (FCM)

1. Firebase Console → Project Settings → Cloud Messaging
2. Copy Server Key
3. Add to backend environment variables:
   ```bash
   FCM_SERVER_KEY=your_server_key
   ```

## Step 6: Set Up Crash Reporting

### Sentry Integration

```bash
npm install @sentry/react-native
```

Configure in `App.js`:
```javascript
import * as Sentry from '@sentry/react-native';

Sentry.init({
  dsn: 'YOUR_SENTRY_DSN',
  environment: __DEV__ ? 'development' : 'production',
  tracesSampleRate: 1.0,
});
```

## Step 7: Over-The-Air (OTA) Updates

EAS Update allows pushing updates without app store review:

```bash
# Configure
eas update:configure

# Publish update
eas update --branch production --message "Bug fixes"
```

Users get updates automatically on next app launch.

## Step 8: Monitor and Maintain

### Analytics

Integrate analytics:
```bash
npm install @react-native-firebase/analytics
```

Track key metrics:
- Daily active users
- Incident reports per day
- Verification rate
- Crash-free rate
- Session duration

### App Store Optimization (ASO)

- Monitor keyword rankings
- A/B test screenshots
- Respond to reviews
- Update regularly (every 2-4 weeks)

### Version Updates

When releasing new version:

1. Update version in `app.json`:
   ```json
   {
     "version": "1.1.0",
     "ios": { "buildNumber": "2" },
     "android": { "versionCode": 2 }
   }
   ```

2. Build and submit:
   ```bash
   eas build --platform all --profile production
   eas submit --platform all --profile production
   ```

## Troubleshooting

### Build Fails

Check EAS build logs:
```bash
eas build:list
eas build:view <build-id>
```

Common issues:
- Missing credentials: Run `eas credentials`
- Native module errors: Clear cache and rebuild
- Memory issues: Upgrade EAS plan

### App Rejected

Common rejection reasons:
- Missing privacy policy
- Incomplete app description
- Crashes on launch
- Inappropriate content
- Missing required screenshots

Fix issues and resubmit.

### Push Notifications Not Working

1. Verify FCM/APNs credentials
2. Check device permissions
3. Test with Expo push notification tool:
   ```bash
   npx expo-notifications-test
   ```

## Cost Estimation

**One-Time Costs:**
- Apple Developer: $99/year
- Google Play Developer: $25 one-time

**Monthly Costs:**
- EAS Build: Free tier (30 builds/month) or $29/month (unlimited)
- EAS Submit: Free
- EAS Update: Free tier or $29/month
- Firebase: Free tier (Spark) or $25/month (Blaze)
- Sentry: Free tier or $26/month

**Total:**
- Year 1: ~$150-500 (depending on services)
- Ongoing: ~$100-200/year

## Next Steps

1. Set up app analytics
2. Configure deep linking
3. Implement in-app purchases (for Premium)
4. Set up A/B testing
5. Create marketing materials
6. Plan launch campaign

## Support Resources

- Expo Docs: https://docs.expo.dev
- EAS Build: https://docs.expo.dev/build/introduction/
- App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Google Play Policies: https://play.google.com/about/developer-content-policy/
