# Hotspot Mobile App

Cross-platform mobile application for iOS and Android built with React Native and Expo.

## 🏗️ Architecture

- **Framework**: React Native 0.74 with Expo SDK 51
- **Navigation**: React Navigation 6
- **State Management**: Zustand
- **Server State**: React Query (TanStack Query)
- **Styling**: NativeWind (Tailwind CSS for React Native)
- **Maps**: React Map GL with MapLibre GL
- **Real-time**: Socket.IO Client
- **Authentication**: Async Storage + JWT
- **Push Notifications**: Expo Notifications + FCM
- **Image Handling**: Expo Image Picker + Image Manipulator
- **Location**: Expo Location with background tracking

## 📱 Features

### Core Functionality

- **Real-time Map View** - Interactive map with incident markers and hotspot zones
- **Quick Reporting** - One-tap incident reporting with GPS auto-capture
- **Incident Feed** - Chronological list with filtering by type and time
- **Push Notifications** - Alerts for nearby incidents and hotspot zone entry
- **Community Verification** - Upvote incidents to build trust
- **Analytics Dashboard** - Safety statistics and trend visualization
- **Offline Support** - Queue reports and cache map tiles when offline
- **Premium Features** - Extended radius, Travel Mode, SOS button

### User Experience

- **Geofenced Alerts** - Automatic notifications when entering danger zones
- **Risk Level Indicators** - Color-coded zones (Low, Medium, High, Critical)
- **Background Location** - Track location even when app is closed (Premium)
- **Dark Mode** - Night-friendly UI for safe driving
- **Haptic Feedback** - Tactile responses for key interactions
- **Pull-to-Refresh** - Update incident feed with gesture

## 🚀 Getting Started

### Prerequisites

- Node.js 20.x or higher
- npm or yarn
- Expo CLI (`npm install -g expo-cli`)
- iOS Simulator (Mac only) or Android Studio
- Expo Go app on physical device (for testing)

### Installation

1. **Install dependencies**
   ```bash
   cd hotspot_mobile
   npm install
   ```

2. **Configure environment variables**
   ```bash
   cp .env.example .env
   ```

   Edit `.env`:
   ```bash
   EXPO_PUBLIC_API_URL=http://localhost:4000/api
   EXPO_PUBLIC_WS_URL=ws://localhost:4000/socket
   EXPO_PUBLIC_MAPLIBRE_STYLE_URL=https://tiles.example.com/style.json
   EXPO_PUBLIC_FCM_SENDER_ID=your_fcm_sender_id
   ```

3. **Start the development server**
   ```bash
   npx expo start
   ```

   Or with specific platform:
   ```bash
   npx expo start --ios      # iOS Simulator
   npx expo start --android  # Android Emulator
   npx expo start --web      # Web browser
   ```

4. **Run on physical device**
   - Install Expo Go from App Store / Play Store
   - Scan QR code from terminal
   - Shake device to open developer menu

## 📂 Project Structure

```
hotspot_mobile/
├── app/                    # Expo Router app directory
│   ├── (auth)/            # Authentication screens
│   ├── (tabs)/            # Main tab navigation
│   ├── _layout.tsx        # Root layout
│   └── index.tsx          # Entry point
├── components/            # Reusable components
│   ├── map/              # Map-related components
│   ├── incidents/        # Incident components
│   ├── ui/               # UI primitives
│   └── shared/           # Shared components
├── hooks/                # Custom React hooks
│   ├── useLocation.ts
│   ├── useIncidents.ts
│   ├── useGeofencing.ts
│   └── useNotifications.ts
├── services/             # API and external services
│   ├── api.ts           # REST API client
│   ├── socket.ts        # WebSocket client
│   ├── location.ts      # Location services
│   └── notifications.ts # Push notifications
├── stores/              # Zustand state stores
│   ├── authStore.ts
│   ├── incidentStore.ts
│   └── settingsStore.ts
├── utils/               # Utility functions
│   ├── geospatial.ts   # Distance calculations
│   ├── formatting.ts   # Date/time formatting
│   └── validation.ts   # Input validation
├── constants/           # App constants
│   ├── Colors.ts
│   ├── IncidentTypes.ts
│   └── Config.ts
├── assets/              # Static assets
│   ├── images/
│   ├── icons/
│   └── fonts/
├── app.json            # Expo configuration
├── package.json        # Dependencies
└── tailwind.config.js  # NativeWind configuration
```

## 🗺️ Key Screens

### Map Screen (Home)
- Interactive map with MapLibre GL
- Color-coded incident markers (red, orange, blue)
- Hotspot zone overlays with opacity based on risk
- Floating "+ Report Incident" button
- User location marker
- Map controls (zoom, center, layers)

### Report Screen
- Auto-captured GPS coordinates
- Incident type selector (Hijacking, Mugging, Accident)
- Optional description input (280 chars)
- Optional photo attachment
- Submit button with loading state
- Offline queue indicator

### Feed Screen
- Virtualized list of nearby incidents
- Filter controls (type, time range)
- Distance from user location
- Time ago formatting
- Pull-to-refresh
- Incident detail modal on tap

### Analytics Screen
- Top 5 hotspot areas
- Peak hours chart by incident type
- Weekly trend graph
- Heatmap density view
- Premium upsell for city-wide data

### Settings Screen
- Notification preferences
- Alert radius slider (1-10km)
- Incident type toggles
- Account management
- Premium subscription status
- Dark mode toggle

### Premium Features
- Travel Mode: Pre-trip safety summary
- SOS Button: Share location with emergency contacts
- Extended Analytics: City/province-wide data
- Background Notifications: Alerts when app is closed

## 🔌 API Integration

### REST API Client
```typescript
// services/api.ts
import axios from 'axios';

const api = axios.create({
  baseURL: process.env.EXPO_PUBLIC_API_URL,
  timeout: 10000,
});

// Add auth token interceptor
api.interceptors.request.use((config) => {
  const token = getAuthToken();
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

export const incidentsAPI = {
  getNearby: (lat, lng, radius) => 
    api.get(`/incidents/nearby?lat=${lat}&lng=${lng}&radius=${radius}`),
  create: (data) => api.post('/incidents', data),
  verify: (id) => api.post(`/incidents/${id}/verify`),
};
```

### WebSocket Client
```typescript
// services/socket.ts
import { io } from 'socket.io-client';

const socket = io(process.env.EXPO_PUBLIC_WS_URL, {
  transports: ['websocket'],
  autoConnect: false,
});

export const subscribeToIncidents = (location) => {
  socket.emit('incident:subscribe', { location });
};

export const onNewIncident = (callback) => {
  socket.on('incident:new', callback);
};

export const onZoneEntered = (callback) => {
  socket.on('zone:entered', callback);
};
```

## 📍 Location Services

### Foreground Location
```typescript
// hooks/useLocation.ts
import * as Location from 'expo-location';

export const useLocation = () => {
  const [location, setLocation] = useState(null);

  useEffect(() => {
    (async () => {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status === 'granted') {
        const loc = await Location.getCurrentPositionAsync({});
        setLocation(loc.coords);
      }
    })();
  }, []);

  return location;
};
```

### Background Location (Premium)
```typescript
// services/location.ts
import * as Location from 'expo-location';
import * as TaskManager from 'expo-task-manager';

const LOCATION_TASK_NAME = 'background-location-task';

TaskManager.defineTask(LOCATION_TASK_NAME, async ({ data, error }) => {
  if (error) {
    console.error(error);
    return;
  }
  if (data) {
    const { locations } = data;
    // Check for hotspot zone entry
    await checkGeofencing(locations[0].coords);
  }
});

export const startBackgroundLocation = async () => {
  await Location.startLocationUpdatesAsync(LOCATION_TASK_NAME, {
    accuracy: Location.Accuracy.Balanced,
    timeInterval: 30000, // 30 seconds
    distanceInterval: 100, // 100 meters
    foregroundService: {
      notificationTitle: 'Hotspot is tracking your location',
      notificationBody: 'Monitoring for nearby safety incidents',
    },
  });
};
```

## 🔔 Push Notifications

### Setup
```typescript
// services/notifications.ts
import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';

export const registerForPushNotifications = async () => {
  if (!Device.isDevice) {
    return null;
  }

  const { status: existingStatus } = await Notifications.getPermissionsAsync();
  let finalStatus = existingStatus;

  if (existingStatus !== 'granted') {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }

  if (finalStatus !== 'granted') {
    return null;
  }

  const token = (await Notifications.getExpoPushTokenAsync()).data;
  
  // Register token with backend
  await api.post('/notifications/register-token', { token });

  return token;
};

// Handle notifications
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
  }),
});
```

### Notification Formats
```typescript
// Hotspot zone entry
{
  title: "⚠️ Entering HIGH RISK Zone",
  body: "15 Hijackings reported in this area in the past 7 days. Stay alert.",
  data: { zoneId: "zone-123", riskLevel: "high" }
}

// Nearby incident
{
  title: "🚨 Hijacking Reported Nearby",
  body: "0.8 km away - Reported 2 minutes ago",
  data: { incidentId: "incident-456", distance: 800 }
}
```

## 🧪 Testing

```bash
# Run tests
npm test

# Run tests with coverage
npm test -- --coverage

# Run specific test file
npm test -- MapView.test.tsx

# Run E2E tests (Detox)
npm run test:e2e:ios
npm run test:e2e:android
```

### Test Structure
```
__tests__/
├── components/
│   ├── MapView.test.tsx
│   ├── IncidentFeed.test.tsx
│   └── ReportButton.test.tsx
├── hooks/
│   ├── useLocation.test.ts
│   └── useIncidents.test.ts
├── services/
│   ├── api.test.ts
│   └── socket.test.ts
└── e2e/
    ├── auth.e2e.ts
    ├── reporting.e2e.ts
    └── notifications.e2e.ts
```

## 📦 Building for Production

### iOS

1. **Configure app.json**
   ```json
   {
     "expo": {
       "ios": {
         "bundleIdentifier": "com.hotspot.app",
         "buildNumber": "1.0.0"
       }
     }
   }
   ```

2. **Build with EAS**
   ```bash
   eas build --platform ios --profile production
   ```

3. **Submit to App Store**
   ```bash
   eas submit --platform ios
   ```

### Android

1. **Configure app.json**
   ```json
   {
     "expo": {
       "android": {
         "package": "com.hotspot.app",
         "versionCode": 1
       }
     }
   }
   ```

2. **Build with EAS**
   ```bash
   eas build --platform android --profile production
   ```

3. **Submit to Play Store**
   ```bash
   eas submit --platform android
   ```

## 🎨 Styling with NativeWind

```tsx
// Example component
import { View, Text } from 'react-native';

export const IncidentCard = ({ incident }) => {
  return (
    <View className="bg-white dark:bg-gray-800 rounded-lg p-4 shadow-md">
      <Text className="text-lg font-bold text-gray-900 dark:text-white">
        {incident.type}
      </Text>
      <Text className="text-sm text-gray-600 dark:text-gray-400">
        {incident.distance}km away • {incident.timeAgo}
      </Text>
    </View>
  );
};
```

## 🔒 Security

- JWT tokens stored securely in Expo SecureStore
- API keys in environment variables (not committed)
- Photo uploads compressed and validated
- Location permissions requested with clear explanations
- Sensitive data encrypted at rest
- SSL pinning for API requests

## 🐛 Debugging

```bash
# View logs
npx expo start --dev-client

# Remote debugging
# Shake device → "Debug Remote JS"

# React Native Debugger
npm install -g react-native-debugger
react-native-debugger

# Network inspection
# Shake device → "Toggle Inspector"
```

## 📚 Additional Resources

- [Expo Documentation](https://docs.expo.dev/)
- [React Native Docs](https://reactnative.dev/)
- [MapLibre GL Native](https://maplibre.org/)
- [React Navigation](https://reactnavigation.org/)
- [NativeWind](https://www.nativewind.dev/)

## 🤝 Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) in the root directory.

## 📄 License

MIT License - see [LICENSE](../LICENSE) file for details.
