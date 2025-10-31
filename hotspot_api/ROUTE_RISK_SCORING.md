# Route Risk Scoring Feature

## Overview

The Route Risk Scoring feature provides comprehensive safety analysis for planned routes, helping users make informed decisions about their travel paths. This premium feature analyzes historical incident data, hotspot zones, and provides real-time updates during active journeys.

## Features

### 1. Route Safety Analysis
- **Comprehensive Risk Assessment**: Analyzes routes based on incidents from the past 48 hours
- **Safety Score**: 0-100 scale (higher is safer)
- **Risk Levels**: Safe (80+), Moderate (60-79), Caution (40-59), Dangerous (<40)
- **Incident Breakdown**: Counts by type (hijacking, mugging, accident)
- **Hotspot Zone Detection**: Identifies active hotspot zones along the route

### 2. Route Segment Analysis
- **5-Segment Breakdown**: Divides route into 5 equal segments
- **Per-Segment Risk Scores**: Individual safety scores for each segment
- **Critical Zone Alerts**: Highlights segments with critical hotspot zones
- **Incident Distribution**: Shows incident counts per segment

### 3. Alternative Route Suggestions
- **3 Alternative Routes**: Northern, Southern, and Eastern detours
- **Comparative Analysis**: Side-by-side safety scores
- **Detour Distance**: Shows additional kilometers for each alternative
- **Smart Recommendations**: Suggests safer alternatives when direct route is risky

### 4. Real-Time Journey Updates
- **Live Incident Alerts**: Notifications for incidents reported in last 10 minutes
- **Approaching Zone Warnings**: Alerts when approaching hotspot zones (2km ahead)
- **Remaining Route Score**: Updated safety score for remaining journey
- **30-Second Polling**: Automatic updates every 30 seconds during active journey

## API Endpoints

### 1. Analyze Route Safety
```
POST /api/v1/travel/analyze-route
POST /api/travel/analyze-route (legacy)
```

**Request Body:**
```json
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

**Response:**
```json
{
  "success": true,
  "data": {
    "safety_score": 75,
    "risk_level": "moderate",
    "total_incidents": 8,
    "incident_counts": {
      "hijacking": 2,
      "mugging": 4,
      "accident": 2
    },
    "hotspot_zones": {
      "total": 2,
      "critical": 0,
      "high": 1,
      "medium": 1,
      "low": 0
    },
    "zones": [...],
    "segments": [
      {
        "segment_number": 1,
        "start_location": {...},
        "end_location": {...},
        "safety_score": 85,
        "risk_level": "safe",
        "incident_count": 1,
        "hotspot_zones": 0,
        "critical_zones": 0,
        "high_risk_zones": 0
      },
      ...
    ],
    "recommendations": [
      "Route appears safe based on recent activity"
    ]
  }
}
```

### 2. Get Alternative Routes
```
POST /api/v1/travel/alternative-routes
POST /api/travel/alternative-routes (legacy)
```

**Request Body:**
```json
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

**Response:**
```json
{
  "success": true,
  "data": {
    "direct_route": {
      "route_name": "Direct Route",
      "waypoints": [...],
      "safety_score": 75,
      "total_incidents": 8,
      "total_zones": 2,
      "estimated_detour_km": 0
    },
    "alternative_routes": [
      {
        "route_name": "Northern Route",
        "waypoints": [...],
        "safety_score": 88,
        "total_incidents": 3,
        "total_zones": 1,
        "estimated_detour_km": 2.5
      },
      ...
    ],
    "recommendation": "Consider taking an alternative route for better safety"
  }
}
```

### 3. Get Real-Time Updates
```
POST /api/v1/travel/realtime-updates
POST /api/travel/realtime-updates (legacy)
```

**Request Body:**
```json
{
  "current_location": {
    "latitude": -26.1558,
    "longitude": 28.0520
  },
  "destination": {
    "latitude": -26.1076,
    "longitude": 28.0567
  },
  "radius": 1000
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "remaining_route": {
      "safety_score": 82,
      "risk_level": "safe",
      ...
    },
    "recent_incidents": [
      {
        "id": "...",
        "type": "mugging",
        "distance_meters": 1200,
        "minutes_ago": 5,
        "location": {...}
      }
    ],
    "approaching_zones": [
      {
        "id": "...",
        "type": "hijacking",
        "risk_level": "high",
        "distance_meters": 1800,
        "location": {...}
      }
    ],
    "alerts": [
      "1 incident(s) reported nearby recently",
      "Approaching high risk zone in 1.8km"
    ]
  }
}
```

## Algorithm Details

### Safety Score Calculation
```elixir
# Start with perfect score
score = 100

# Deduct 2 points per incident
score = score - (incident_count * 2)

# Deduct points for hotspot zones
# - Critical: -20 points
# - High: -10 points
# - Medium: -5 points
# - Low: -2 points

# Clamp between 0 and 100
score = max(0, min(100, score))
```

### Route Segmentation
- Route divided into 5 equal segments
- Each segment analyzed independently
- Incidents within radius of segment endpoints counted
- Hotspot zones intersecting segment included

### Alternative Route Generation
- 3 alternative routes generated with 10% detour
- Northern route: waypoint at midpoint + 10% north
- Southern route: waypoint at midpoint + 10% south
- Eastern route: waypoint at midpoint + 10% east
- Each alternative analyzed for safety
- Sorted by safety score (highest first)

### Real-Time Updates
- Checks for incidents in last 10 minutes
- Alerts for zones within 2km ahead
- Recalculates remaining route safety
- Generates contextual alerts

## Mobile Integration

### Navigation Integration
The mobile app integrates with:
- **Google Maps**: Opens with route and waypoints
- **Apple Maps**: Opens with destination (iOS only)

### User Flow
1. User enters destination address
2. App geocodes address to coordinates
3. User taps "Analyze Route Safety"
4. App displays safety report with segments
5. User can view alternative routes
6. User taps "Start Journey"
7. App offers to open navigation
8. Real-time updates every 30 seconds
9. Critical alerts shown immediately
10. User taps "Stop Journey" when arrived

### UI Components
- **Safety Score Badge**: Color-coded by risk level
- **Incident Summary**: Grid showing counts by type
- **Hotspot Zones**: Total and breakdown by risk level
- **Segment Cards**: Expandable list of route segments
- **Alternative Routes**: Expandable comparison cards
- **Real-Time Alerts**: Banner notifications
- **Recent Incidents**: List with distance and time
- **Approaching Zones**: List with distance ahead

## Premium Feature

Route Risk Scoring is a **premium-only feature**. Free users will receive:
- HTTP 403 Forbidden response
- Error message: "Travel Mode is a premium feature. Please upgrade your subscription."

## Performance Considerations

### Database Queries
- Uses bounding box queries for efficiency
- Filters incidents from last 48 hours only
- Indexes on latitude, longitude, and inserted_at
- Active zones only (is_active = true)

### Caching Opportunities
- Route analysis results can be cached for 5 minutes
- Alternative routes can be cached for 10 minutes
- Real-time updates should NOT be cached

### Rate Limiting
- Analyze route: 10 requests per minute per user
- Alternative routes: 5 requests per minute per user
- Real-time updates: 120 requests per hour per user (every 30 seconds)

## Testing

### Manual Testing
```bash
# Test route analysis
curl -X POST http://localhost:4000/api/v1/travel/analyze-route \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "origin": {"latitude": -26.2041, "longitude": 28.0473},
    "destination": {"latitude": -26.1076, "longitude": 28.0567}
  }'

# Test alternative routes
curl -X POST http://localhost:4000/api/v1/travel/alternative-routes \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "origin": {"latitude": -26.2041, "longitude": 28.0473},
    "destination": {"latitude": -26.1076, "longitude": 28.0567}
  }'

# Test real-time updates
curl -X POST http://localhost:4000/api/v1/travel/realtime-updates \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "current_location": {"latitude": -26.1558, "longitude": 28.0520},
    "destination": {"latitude": -26.1076, "longitude": 28.0567}
  }'
```

### Unit Tests
See `test/hotspot_api/travel_test.exs` for comprehensive test coverage.

## Future Enhancements

1. **Machine Learning Risk Prediction**
   - Train model on historical incident patterns
   - Predict future risk based on time of day, day of week
   - Weather-based risk adjustments

2. **Traffic Integration**
   - Combine safety scores with traffic data
   - Suggest routes that balance safety and travel time

3. **Community Route Ratings**
   - Allow users to rate routes they've taken
   - Incorporate user feedback into safety scores

4. **Route History**
   - Save frequently traveled routes
   - Track safety score trends over time
   - Alert when favorite routes become risky

5. **Multi-Stop Routes**
   - Support routes with multiple waypoints
   - Optimize waypoint order for safety

6. **Voice Alerts**
   - Audio notifications during journey
   - Hands-free safety updates

## Support

For issues or questions:
- Backend: Check `hotspot_api/lib/hotspot_api/travel.ex`
- Frontend: Check `hotspot_mobile/src/screens/TravelModeScreen.js`
- API Service: Check `hotspot_mobile/src/services/travelService.js`
