# Emergency Services Locator Setup

This document explains how to set up the Emergency Services Locator feature that uses Google Places API to find nearby police stations and hospitals.

## Features

- Find nearby police stations within a specified radius
- Find nearby hospitals within a specified radius
- Calculate distance and estimated travel time to emergency services
- Cache results for 1 hour to reduce API calls
- Fallback to mock data when API key is not configured (for development/testing)

## Google Places API Setup

### 1. Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable billing for the project (required for Places API)

### 2. Enable Places API

1. Navigate to "APIs & Services" > "Library"
2. Search for "Places API"
3. Click "Enable"

### 3. Create API Credentials

1. Navigate to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "API Key"
3. Copy the generated API key
4. (Recommended) Click "Restrict Key" and:
   - Under "API restrictions", select "Restrict key"
   - Choose "Places API" from the dropdown
   - Under "Application restrictions", you can restrict by:
     - HTTP referrers (for web apps)
     - IP addresses (for server apps)
     - Android apps
     - iOS apps

### 4. Configure Environment Variable

Add the API key to your `.env` file:

```bash
GOOGLE_PLACES_API_KEY=your_actual_api_key_here
```

For production, set this environment variable in your hosting platform (Render, Fly.io, etc.).

## API Endpoints

### Get All Nearby Emergency Services

```
GET /api/emergency-services/nearby?lat={latitude}&lng={longitude}&radius={radius}
```

**Query Parameters:**
- `lat` (required): Latitude of the location
- `lng` (required): Longitude of the location
- `radius` (optional): Search radius in meters (default: 5000)

**Response:**
```json
{
  "data": {
    "police_stations": [
      {
        "place_id": "ChIJ...",
        "name": "Central Police Station",
        "address": "123 Main Street",
        "location": {
          "latitude": -26.2041,
          "longitude": 28.0473
        },
        "rating": 4.2,
        "open_now": true,
        "types": ["police", "point_of_interest"],
        "distance_meters": 1234,
        "distance_text": "1.2 km",
        "duration_seconds": 111,
        "duration_text": "1 min"
      }
    ],
    "hospitals": [
      {
        "place_id": "ChIJ...",
        "name": "City General Hospital",
        "address": "789 Hospital Road",
        "location": {
          "latitude": -26.2041,
          "longitude": 28.0473
        },
        "rating": 4.5,
        "open_now": true,
        "types": ["hospital", "health", "point_of_interest"],
        "distance_meters": 2345,
        "distance_text": "2.3 km",
        "duration_seconds": 211,
        "duration_text": "3 min"
      }
    ]
  },
  "user_location": {
    "latitude": -26.2041,
    "longitude": 28.0473
  }
}
```

### Get Nearby Police Stations Only

```
GET /api/emergency-services/police?lat={latitude}&lng={longitude}&radius={radius}
```

### Get Nearby Hospitals Only

```
GET /api/emergency-services/hospitals?lat={latitude}&lng={longitude}&radius={radius}
```

## Pricing

Google Places API pricing (as of 2024):
- **Nearby Search**: $32 per 1,000 requests
- **Free tier**: $200 monthly credit (approximately 6,250 requests)

### Cost Optimization

The implementation includes several cost-saving measures:

1. **Caching**: Results are cached for 1 hour, reducing duplicate API calls
2. **Radius limits**: Default radius is 5km (can be adjusted)
3. **Separate endpoints**: Allows fetching only police stations or hospitals when needed
4. **Mock data fallback**: Development/testing doesn't consume API quota

### Estimated Costs

Assuming:
- 1,000 active users per day
- Each user checks emergency services once per day
- Cache hit rate of 50%

Monthly cost: ~$16 (500 requests/day × 30 days × $32/1000)

## Mobile App Integration

The mobile app includes an `EmergencyServicesModal` component that:

1. Shows a "Find Help Nearby" button on incident details
2. Displays nearby police stations and hospitals in tabs
3. Shows distance and estimated travel time for each service
4. Provides one-tap directions to any emergency service
5. Indicates if services are currently open

### Usage in Mobile App

```javascript
import EmergencyServicesModal from '../components/EmergencyServicesModal';

// In your component
const [modalVisible, setModalVisible] = useState(false);

<EmergencyServicesModal
  visible={modalVisible}
  onClose={() => setModalVisible(false)}
  latitude={userLocation.latitude}
  longitude={userLocation.longitude}
/>
```

## Testing

Run the test suite:

```bash
mix test test/hotspot_api/emergency_services_test.exs
```

The tests use mock data and don't require an API key.

## Troubleshooting

### "Google Places API key not configured" warning

This is expected in development if you haven't set the `GOOGLE_PLACES_API_KEY` environment variable. The system will use mock data instead.

### API returns "ZERO_RESULTS"

This means no emergency services were found within the specified radius. Try:
- Increasing the search radius
- Checking if the coordinates are valid
- Verifying the location has emergency services nearby

### API returns error status

Common error statuses:
- `OVER_QUERY_LIMIT`: You've exceeded your API quota
- `REQUEST_DENIED`: API key is invalid or Places API is not enabled
- `INVALID_REQUEST`: Missing required parameters

Check the Phoenix logs for detailed error messages.

## Security Considerations

1. **Never expose API key in client-side code**: The API key should only be used server-side
2. **Restrict API key**: Use Google Cloud Console to restrict the key to specific APIs and IP addresses
3. **Monitor usage**: Set up billing alerts in Google Cloud Console
4. **Rate limiting**: The API endpoints are protected by authentication middleware

## Future Enhancements

Potential improvements:
- Add more emergency service types (fire stations, pharmacies)
- Implement place details API for phone numbers and hours
- Add user reviews and photos
- Support for alternative map providers (OpenStreetMap, Mapbox)
- Offline caching of frequently accessed emergency services
