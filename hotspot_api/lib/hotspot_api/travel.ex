defmodule HotspotApi.Travel do
  @moduledoc """
  The Travel context for premium features like route safety analysis.
  """

  import Ecto.Query, warn: false
  alias HotspotApi.Repo
  alias HotspotApi.Incidents.Incident
  alias HotspotApi.Geofencing.HotspotZone

  @doc """
  Analyze route safety between origin and destination.
  Returns a safety summary with incident counts and hotspot zones along the route.
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
      recommendations: generate_recommendations(safety_score, route_incidents, route_zones)
    }
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
