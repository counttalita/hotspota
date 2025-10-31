defmodule HotspotApi.Travel do
  @moduledoc """
  The Travel context for premium features like route safety analysis.
  """

  import Ecto.Query, warn: false
  alias HotspotApi.Repo
  alias HotspotApi.Incidents.Incident
  alias HotspotApi.Geofencing.HotspotZone

  @doc """
  Analyze route safety between origin and destination with detailed segment breakdown.
  Returns a comprehensive safety summary with incident counts, hotspot zones, and segment analysis.
  """
  def analyze_route_safety(origin_lat, origin_lng, dest_lat, dest_lng, radius_meters \\ 1000) do
    # Calculate bounding box for the route
    {min_lat, max_lat, min_lng, max_lng} = calculate_route_bounding_box(
      origin_lat, origin_lng, dest_lat, dest_lng, radius_meters
    )

    # Get incidents along the route (last 48 hours)
    two_days_ago = DateTime.utc_now() |> DateTime.add(-48 * 3600, :second)

    incidents =
      from(i in Incident,
        where: i.latitude >= ^min_lat and i.latitude <= ^max_lat,
        where: i.longitude >= ^min_lng and i.longitude <= ^max_lng,
        where: i.inserted_at > ^two_days_ago,
        where: i.expires_at > ^DateTime.utc_now()
      )
      |> Repo.all()

    # Filter incidents within radius of route line
    route_incidents = Enum.filter(incidents, fn incident ->
      distance_to_route(incident.latitude, incident.longitude, origin_lat, origin_lng, dest_lat, dest_lng) <= radius_meters
    end)

    # Get active hotspot zones along the route
    hotspot_zones =
      from(z in HotspotZone,
        where: z.center_latitude >= ^min_lat and z.center_latitude <= ^max_lat,
        where: z.center_longitude >= ^min_lng and z.center_longitude <= ^max_lng,
        where: z.is_active == true
      )
      |> Repo.all()

    # Filter zones within radius of route
    route_zones = Enum.filter(hotspot_zones, fn zone ->
      distance_to_route(zone.center_latitude, zone.center_longitude, origin_lat, origin_lng, dest_lat, dest_lng) <= (zone.radius_meters + radius_meters)
    end)

    # Calculate safety score (0-100, higher is safer)
    safety_score = calculate_safety_score(route_incidents, route_zones)

    # Group incidents by type
    incident_counts = Enum.group_by(route_incidents, & &1.type)
    |> Enum.map(fn {type, incidents} -> {type, length(incidents)} end)
    |> Enum.into(%{})

    # Group zones by risk level
    zone_counts = Enum.group_by(route_zones, & &1.risk_level)
    |> Enum.map(fn {level, zones} -> {level, length(zones)} end)
    |> Enum.into(%{})

    # Analyze route segments for detailed risk breakdown
    segments = analyze_route_segments(origin_lat, origin_lng, dest_lat, dest_lng, route_incidents, route_zones, radius_meters)

    %{
      safety_score: safety_score,
      risk_level: get_risk_level(safety_score),
      total_incidents: length(route_incidents),
      incident_counts: %{
        hijacking: Map.get(incident_counts, "hijacking", 0),
        mugging: Map.get(incident_counts, "mugging", 0),
        accident: Map.get(incident_counts, "accident", 0)
      },
      hotspot_zones: %{
        total: length(route_zones),
        critical: Map.get(zone_counts, "critical", 0),
        high: Map.get(zone_counts, "high", 0),
        medium: Map.get(zone_counts, "medium", 0),
        low: Map.get(zone_counts, "low", 0)
      },
      zones: Enum.map(route_zones, fn zone ->
        %{
          id: zone.id,
          type: zone.zone_type,
          risk_level: zone.risk_level,
          incident_count: zone.incident_count,
          location: %{
            latitude: zone.center_latitude,
            longitude: zone.center_longitude
          }
        }
      end),
      segments: segments,
      recommendations: generate_recommendations(safety_score, route_incidents, route_zones)
    }
  end

  @doc """
  Analyze route segments to provide detailed risk breakdown along the route.
  Divides the route into segments and calculates risk for each segment.
  """
  def analyze_route_segments(origin_lat, origin_lng, dest_lat, dest_lng, incidents, zones, radius_meters) do
    # Divide route into 5 segments for analysis
    num_segments = 5

    segments = for i <- 0..(num_segments - 1) do
      # Calculate segment start and end points
      progress_start = i / num_segments
      progress_end = (i + 1) / num_segments

      seg_start_lat = origin_lat + (dest_lat - origin_lat) * progress_start
      seg_start_lng = origin_lng + (dest_lng - origin_lng) * progress_start
      seg_end_lat = origin_lat + (dest_lat - origin_lat) * progress_end
      seg_end_lng = origin_lng + (dest_lng - origin_lng) * progress_end

      # Find incidents near this segment
      segment_incidents = Enum.filter(incidents, fn incident ->
        dist_to_start = haversine_distance(incident.latitude, incident.longitude, seg_start_lat, seg_start_lng)
        dist_to_end = haversine_distance(incident.latitude, incident.longitude, seg_end_lat, seg_end_lng)
        min(dist_to_start, dist_to_end) <= radius_meters
      end)

      # Find zones intersecting this segment
      segment_zones = Enum.filter(zones, fn zone ->
        dist_to_start = haversine_distance(zone.center_latitude, zone.center_longitude, seg_start_lat, seg_start_lng)
        dist_to_end = haversine_distance(zone.center_latitude, zone.center_longitude, seg_end_lat, seg_end_lng)
        min(dist_to_start, dist_to_end) <= (zone.radius_meters + radius_meters)
      end)

      # Calculate segment safety score
      segment_score = calculate_safety_score(segment_incidents, segment_zones)

      %{
        segment_number: i + 1,
        start_location: %{latitude: seg_start_lat, longitude: seg_start_lng},
        end_location: %{latitude: seg_end_lat, longitude: seg_end_lng},
        safety_score: segment_score,
        risk_level: get_risk_level(segment_score),
        incident_count: length(segment_incidents),
        hotspot_zones: length(segment_zones),
        critical_zones: Enum.count(segment_zones, & &1.risk_level == "critical"),
        high_risk_zones: Enum.count(segment_zones, & &1.risk_level == "high")
      }
    end

    segments
  end

  @doc """
  Generate alternative safer routes by suggesting detours around high-risk areas.
  Returns up to 3 alternative routes with their safety scores.
  """
  def suggest_alternative_routes(origin_lat, origin_lng, dest_lat, dest_lng, radius_meters \\ 1000) do
    # Analyze the direct route
    direct_route = analyze_route_safety(origin_lat, origin_lng, dest_lat, dest_lng, radius_meters)

    # Generate alternative routes by adding waypoints that avoid high-risk zones
    alternatives = []

    # Alternative 1: Route via north (add 10% detour)
    north_waypoint_lat = (origin_lat + dest_lat) / 2 + abs(dest_lat - origin_lat) * 0.1
    north_waypoint_lng = (origin_lng + dest_lng) / 2

    north_route_leg1 = analyze_route_safety(origin_lat, origin_lng, north_waypoint_lat, north_waypoint_lng, radius_meters)
    north_route_leg2 = analyze_route_safety(north_waypoint_lat, north_waypoint_lng, dest_lat, dest_lng, radius_meters)

    north_route = %{
      route_name: "Northern Route",
      waypoints: [
        %{latitude: origin_lat, longitude: origin_lng},
        %{latitude: north_waypoint_lat, longitude: north_waypoint_lng},
        %{latitude: dest_lat, longitude: dest_lng}
      ],
      safety_score: round((north_route_leg1.safety_score + north_route_leg2.safety_score) / 2),
      total_incidents: north_route_leg1.total_incidents + north_route_leg2.total_incidents,
      total_zones: north_route_leg1.hotspot_zones.total + north_route_leg2.hotspot_zones.total,
      estimated_detour_km: calculate_detour_distance(origin_lat, origin_lng, dest_lat, dest_lng, north_waypoint_lat, north_waypoint_lng)
    }

    alternatives = [north_route | alternatives]

    # Alternative 2: Route via south (add 10% detour)
    south_waypoint_lat = (origin_lat + dest_lat) / 2 - abs(dest_lat - origin_lat) * 0.1
    south_waypoint_lng = (origin_lng + dest_lng) / 2

    south_route_leg1 = analyze_route_safety(origin_lat, origin_lng, south_waypoint_lat, south_waypoint_lng, radius_meters)
    south_route_leg2 = analyze_route_safety(south_waypoint_lat, south_waypoint_lng, dest_lat, dest_lng, radius_meters)

    south_route = %{
      route_name: "Southern Route",
      waypoints: [
        %{latitude: origin_lat, longitude: origin_lng},
        %{latitude: south_waypoint_lat, longitude: south_waypoint_lng},
        %{latitude: dest_lat, longitude: dest_lng}
      ],
      safety_score: round((south_route_leg1.safety_score + south_route_leg2.safety_score) / 2),
      total_incidents: south_route_leg1.total_incidents + south_route_leg2.total_incidents,
      total_zones: south_route_leg1.hotspot_zones.total + south_route_leg2.hotspot_zones.total,
      estimated_detour_km: calculate_detour_distance(origin_lat, origin_lng, dest_lat, dest_lng, south_waypoint_lat, south_waypoint_lng)
    }

    alternatives = [south_route | alternatives]

    # Alternative 3: Route via east (add 10% detour)
    east_waypoint_lat = (origin_lat + dest_lat) / 2
    east_waypoint_lng = (origin_lng + dest_lng) / 2 + abs(dest_lng - origin_lng) * 0.1

    east_route_leg1 = analyze_route_safety(origin_lat, origin_lng, east_waypoint_lat, east_waypoint_lng, radius_meters)
    east_route_leg2 = analyze_route_safety(east_waypoint_lat, east_waypoint_lng, dest_lat, dest_lng, radius_meters)

    east_route = %{
      route_name: "Eastern Route",
      waypoints: [
        %{latitude: origin_lat, longitude: origin_lng},
        %{latitude: east_waypoint_lat, longitude: east_waypoint_lng},
        %{latitude: dest_lat, longitude: dest_lng}
      ],
      safety_score: round((east_route_leg1.safety_score + east_route_leg2.safety_score) / 2),
      total_incidents: east_route_leg1.total_incidents + east_route_leg2.total_incidents,
      total_zones: east_route_leg1.hotspot_zones.total + east_route_leg2.hotspot_zones.total,
      estimated_detour_km: calculate_detour_distance(origin_lat, origin_lng, dest_lat, dest_lng, east_waypoint_lat, east_waypoint_lng)
    }

    alternatives = [east_route | alternatives]

    # Sort alternatives by safety score (highest first)
    sorted_alternatives = Enum.sort_by(alternatives, & &1.safety_score, :desc)

    %{
      direct_route: %{
        route_name: "Direct Route",
        waypoints: [
          %{latitude: origin_lat, longitude: origin_lng},
          %{latitude: dest_lat, longitude: dest_lng}
        ],
        safety_score: direct_route.safety_score,
        total_incidents: direct_route.total_incidents,
        total_zones: direct_route.hotspot_zones.total,
        estimated_detour_km: 0
      },
      alternative_routes: sorted_alternatives,
      recommendation: if direct_route.safety_score < 60 and Enum.any?(sorted_alternatives, & &1.safety_score > direct_route.safety_score + 10) do
        "Consider taking an alternative route for better safety"
      else
        "Direct route is the safest option"
      end
    }
  end

  @doc """
  Get real-time route risk updates for an active journey.
  This can be called periodically during travel to get updated risk information.
  """
  def get_realtime_route_updates(current_lat, current_lng, dest_lat, dest_lng, radius_meters \\ 1000) do
    # Analyze remaining route from current position to destination
    remaining_route = analyze_route_safety(current_lat, current_lng, dest_lat, dest_lng, radius_meters)

    # Check for new incidents in the last 10 minutes near current location
    ten_minutes_ago = DateTime.utc_now() |> DateTime.add(-10 * 60, :second)

    recent_incidents =
      from(i in Incident,
        where: i.inserted_at > ^ten_minutes_ago,
        where: i.expires_at > ^DateTime.utc_now()
      )
      |> Repo.all()
      |> Enum.filter(fn incident ->
        haversine_distance(incident.latitude, incident.longitude, current_lat, current_lng) <= radius_meters * 5
      end)

    # Check if approaching any hotspot zones
    approaching_zones =
      from(z in HotspotZone,
        where: z.is_active == true
      )
      |> Repo.all()
      |> Enum.filter(fn zone ->
        distance = haversine_distance(zone.center_latitude, zone.center_longitude, current_lat, current_lng)
        # Alert if within 2km of a zone
        distance <= 2000 and distance > zone.radius_meters
      end)
      |> Enum.sort_by(fn zone ->
        haversine_distance(zone.center_latitude, zone.center_longitude, current_lat, current_lng)
      end)

    %{
      remaining_route: remaining_route,
      recent_incidents: Enum.map(recent_incidents, fn incident ->
        %{
          id: incident.id,
          type: incident.type,
          distance_meters: round(haversine_distance(incident.latitude, incident.longitude, current_lat, current_lng)),
          minutes_ago: round(DateTime.diff(DateTime.utc_now(), incident.inserted_at) / 60),
          location: %{
            latitude: incident.latitude,
            longitude: incident.longitude
          }
        }
      end),
      approaching_zones: Enum.map(approaching_zones, fn zone ->
        %{
          id: zone.id,
          type: zone.zone_type,
          risk_level: zone.risk_level,
          distance_meters: round(haversine_distance(zone.center_latitude, zone.center_longitude, current_lat, current_lng)),
          location: %{
            latitude: zone.center_latitude,
            longitude: zone.center_longitude
          }
        }
      end),
      alerts: generate_realtime_alerts(recent_incidents, approaching_zones)
    }
  end

  defp calculate_detour_distance(origin_lat, origin_lng, dest_lat, dest_lng, waypoint_lat, waypoint_lng) do
    # Calculate direct distance
    direct_distance = haversine_distance(origin_lat, origin_lng, dest_lat, dest_lng)

    # Calculate distance via waypoint
    leg1_distance = haversine_distance(origin_lat, origin_lng, waypoint_lat, waypoint_lng)
    leg2_distance = haversine_distance(waypoint_lat, waypoint_lng, dest_lat, dest_lng)
    waypoint_distance = leg1_distance + leg2_distance

    # Return detour in kilometers
    (waypoint_distance - direct_distance) / 1000
    |> Float.round(1)
  end

  defp generate_realtime_alerts(recent_incidents, approaching_zones) do
    alerts = []

    # Alert for recent incidents
    alerts = if length(recent_incidents) > 0 do
      critical_incidents = Enum.filter(recent_incidents, & &1.type == "hijacking")
      if length(critical_incidents) > 0 do
        ["⚠️ #{length(critical_incidents)} hijacking(s) reported nearby in the last 10 minutes" | alerts]
      else
        ["#{length(recent_incidents)} incident(s) reported nearby recently" | alerts]
      end
    else
      alerts
    end

    # Alert for approaching zones
    alerts = if length(approaching_zones) > 0 do
      critical_zones = Enum.filter(approaching_zones, & &1.risk_level == "critical")
      if length(critical_zones) > 0 do
        zone = List.first(critical_zones)
        distance_km = Float.round(zone.distance_meters / 1000, 1)
        ["⚠️ Approaching CRITICAL hotspot zone in #{distance_km}km - Consider alternative route" | alerts]
      else
        zone = List.first(approaching_zones)
        distance_km = Float.round(zone.distance_meters / 1000, 1)
        ["Approaching #{zone.risk_level} risk zone in #{distance_km}km" | alerts]
      end
    else
      alerts
    end

    if length(alerts) == 0 do
      ["No immediate safety concerns detected"]
    else
      alerts
    end
  end

  defp calculate_route_bounding_box(lat1, lng1, lat2, lng2, buffer_meters) do
    # Add buffer in degrees (approximate)
    buffer_degrees = buffer_meters / 111_000.0

    min_lat = min(lat1, lat2) - buffer_degrees
    max_lat = max(lat1, lat2) + buffer_degrees
    min_lng = min(lng1, lng2) - buffer_degrees
    max_lng = max(lng1, lng2) + buffer_degrees

    {min_lat, max_lat, min_lng, max_lng}
  end

  defp distance_to_route(point_lat, point_lng, origin_lat, origin_lng, dest_lat, dest_lng) do
    # Calculate perpendicular distance from point to line segment
    # Using simplified approach: distance to closest endpoint or perpendicular distance

    dist_to_origin = haversine_distance(point_lat, point_lng, origin_lat, origin_lng)
    dist_to_dest = haversine_distance(point_lat, point_lng, dest_lat, dest_lng)

    # For simplicity, return minimum distance to either endpoint
    # A more accurate implementation would calculate perpendicular distance
    min(dist_to_origin, dist_to_dest)
  end

  defp haversine_distance(lat1, lon1, lat2, lon2) do
    r = 6_371_000 # Earth's radius in meters

    phi1 = lat1 * :math.pi() / 180
    phi2 = lat2 * :math.pi() / 180
    delta_phi = (lat2 - lat1) * :math.pi() / 180
    delta_lambda = (lon2 - lon1) * :math.pi() / 180

    a = :math.sin(delta_phi / 2) * :math.sin(delta_phi / 2) +
        :math.cos(phi1) * :math.cos(phi2) *
        :math.sin(delta_lambda / 2) * :math.sin(delta_lambda / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))

    r * c
  end

  defp calculate_safety_score(incidents, zones) do
    # Start with perfect score
    score = 100

    # Deduct points for incidents
    score = score - (length(incidents) * 2)

    # Deduct points for hotspot zones based on risk level
    zone_penalty = Enum.reduce(zones, 0, fn zone, acc ->
      case zone.risk_level do
        "critical" -> acc + 20
        "high" -> acc + 10
        "medium" -> acc + 5
        "low" -> acc + 2
        _ -> acc
      end
    end)

    score = score - zone_penalty

    # Ensure score is between 0 and 100
    max(0, min(100, score))
  end

  defp get_risk_level(score) when score >= 80, do: "safe"
  defp get_risk_level(score) when score >= 60, do: "moderate"
  defp get_risk_level(score) when score >= 40, do: "caution"
  defp get_risk_level(_score), do: "dangerous"

  defp generate_recommendations(score, incidents, zones) do
    recommendations = []

    recommendations = if score < 60 do
      ["Consider taking an alternative route" | recommendations]
    else
      recommendations
    end

    recommendations = if length(zones) > 0 do
      critical_zones = Enum.filter(zones, & &1.risk_level == "critical")
      if length(critical_zones) > 0 do
        ["#{length(critical_zones)} critical hotspot zone(s) detected on this route" | recommendations]
      else
        recommendations
      end
    else
      recommendations
    end

    hijackings = Enum.count(incidents, & &1.type == "hijacking")
    recommendations = if hijackings > 3 do
      ["High hijacking activity reported on this route" | recommendations]
    else
      recommendations
    end

    recommendations = if score >= 80 do
      ["Route appears safe based on recent activity" | recommendations]
    else
      recommendations
    end

    if length(recommendations) == 0 do
      ["No specific safety concerns detected"]
    else
      recommendations
    end
  end
end
