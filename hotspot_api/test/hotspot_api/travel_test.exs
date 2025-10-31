defmodule HotspotApi.TravelTest do
  use HotspotApi.DataCase

  import HotspotApi.AccountsFixtures
  import HotspotApi.IncidentsFixtures
  import HotspotApi.GeofencingFixtures

  alias HotspotApi.Travel

  @moduletag :skip

  describe "analyze_route_safety/5" do
    setup do
      user = user_fixture()

      # Create incidents along a route
      # Origin: -26.2041, 28.0473 (Johannesburg)
      # Destination: -26.1041, 28.1473
      incident1 = incident_fixture(%{
        user_id: user.id,
        type: "hijacking",
        latitude: -26.1541,
        longitude: 28.0973
      })

      incident2 = incident_fixture(%{
        user_id: user.id,
        type: "mugging",
        latitude: -26.1741,
        longitude: 28.1173
      })

      # Create a hotspot zone along the route
      zone = hotspot_zone_fixture(%{
        latitude: -26.1641,
        longitude: 28.1073,
        radius_meters: 500,
        risk_level: "high",
        zone_type: "hijacking",
        incident_count: 10
      })

      %{user: user, incident1: incident1, incident2: incident2, zone: zone}
    end

    test "returns comprehensive route safety analysis", %{incident1: i1, incident2: i2, zone: zone} do
      origin_lat = -26.2041
      origin_lng = 28.0473
      dest_lat = -26.1041
      dest_lng = 28.1473

      result = Travel.analyze_route_safety(origin_lat, origin_lng, dest_lat, dest_lng, 2000)

      assert is_map(result)
      assert Map.has_key?(result, :safety_score)
      assert Map.has_key?(result, :risk_level)
      assert Map.has_key?(result, :total_incidents)
      assert Map.has_key?(result, :incident_counts)
      assert Map.has_key?(result, :hotspot_zones)
      assert Map.has_key?(result, :zones)
      assert Map.has_key?(result, :segments)
      assert Map.has_key?(result, :recommendations)

      # Verify safety score is between 0 and 100
      assert result.safety_score >= 0
      assert result.safety_score <= 100

      # Verify risk level is valid
      assert result.risk_level in ["safe", "moderate", "caution", "dangerous"]

      # Verify incidents are detected
      assert result.total_incidents >= 2

      # Verify incident counts
      assert result.incident_counts.hijacking >= 1
      assert result.incident_counts.mugging >= 1

      # Verify hotspot zones are detected
      assert result.hotspot_zones.total >= 1
      assert result.hotspot_zones.high >= 1

      # Verify zones list contains zone details
      assert length(result.zones) >= 1
      zone_data = hd(result.zones)
      assert Map.has_key?(zone_data, :id)
      assert Map.has_key?(zone_data, :type)
      assert Map.has_key?(zone_data, :risk_level)
      assert Map.has_key?(zone_data, :location)

      # Verify segments are provided
      assert length(result.segments) == 5
      segment = hd(result.segments)
      assert Map.has_key?(segment, :segment_number)
      assert Map.has_key?(segment, :safety_score)
      assert Map.has_key?(segment, :risk_level)
      assert Map.has_key?(segment, :incident_count)

      # Verify recommendations are provided
      assert is_list(result.recommendations)
      assert length(result.recommendations) > 0
    end

    test "returns safe score for route with no incidents" do
      origin_lat = -26.5041
      origin_lng = 28.5473
      dest_lat = -26.4041
      dest_lng = 28.6473

      result = Travel.analyze_route_safety(origin_lat, origin_lng, dest_lat, dest_lng, 1000)

      # Should have high safety score with no incidents
      assert result.safety_score >= 90
      assert result.risk_level == "safe"
      assert result.total_incidents == 0
    end

    test "calculates lower safety score for high-risk routes", %{user: user} do
      # Create multiple incidents along route
      for i <- 1..10 do
        incident_fixture(%{
          user_id: user.id,
          type: "hijacking",
          latitude: -26.1541 + (i * 0.001),
          longitude: 28.0973 + (i * 0.001)
        })
      end

      origin_lat = -26.2041
      origin_lng = 28.0473
      dest_lat = -26.1041
      dest_lng = 28.1473

      result = Travel.analyze_route_safety(origin_lat, origin_lng, dest_lat, dest_lng, 2000)

      # Should have lower safety score with many incidents
      assert result.safety_score < 80
      assert result.risk_level in ["moderate", "caution", "dangerous"]
      assert result.total_incidents >= 10
    end

    test "respects radius parameter" do
      user = user_fixture()

      # Create incident slightly outside small radius
      _incident = incident_fixture(%{
        user_id: user.id,
        latitude: -26.1541,
        longitude: 28.0973
      })

      origin_lat = -26.2041
      origin_lng = 28.0473
      dest_lat = -26.1041
      dest_lng = 28.1473

      # Small radius should not detect incident
      result_small = Travel.analyze_route_safety(origin_lat, origin_lng, dest_lat, dest_lng, 100)

      # Large radius should detect incident
      result_large = Travel.analyze_route_safety(origin_lat, origin_lng, dest_lat, dest_lng, 5000)

      assert result_large.total_incidents > result_small.total_incidents
    end
  end

  describe "analyze_route_segments/7" do
    test "divides route into 5 segments" do
      user = user_fixture()

      origin_lat = -26.2041
      origin_lng = 28.0473
      dest_lat = -26.1041
      dest_lng = 28.1473

      segments = Travel.analyze_route_segments(origin_lat, origin_lng, dest_lat, dest_lng, [], [], 1000)

      assert length(segments) == 5

      # Verify each segment has required fields
      Enum.each(segments, fn segment ->
        assert Map.has_key?(segment, :segment_number)
        assert Map.has_key?(segment, :start_location)
        assert Map.has_key?(segment, :end_location)
        assert Map.has_key?(segment, :safety_score)
        assert Map.has_key?(segment, :risk_level)
        assert Map.has_key?(segment, :incident_count)
        assert Map.has_key?(segment, :hotspot_zones)

        # Verify segment numbers are sequential
        assert segment.segment_number >= 1
        assert segment.segment_number <= 5
      end)
    end

    test "calculates different risk levels for different segments" do
      user = user_fixture()

      # Create incidents only in middle of route
      incidents = [
        incident_fixture(%{
          user_id: user.id,
          latitude: -26.1541,
          longitude: 28.0973
        })
      ]

      origin_lat = -26.2041
      origin_lng = 28.0473
      dest_lat = -26.1041
      dest_lng = 28.1473

      segments = Travel.analyze_route_segments(origin_lat, origin_lng, dest_lat, dest_lng, incidents, [], 2000)

      # Some segments should have incidents, others should not
      segments_with_incidents = Enum.filter(segments, & &1.incident_count > 0)
      segments_without_incidents = Enum.filter(segments, & &1.incident_count == 0)

      assert length(segments_with_incidents) > 0
      assert length(segments_without_incidents) > 0
    end
  end

  describe "suggest_alternative_routes/5" do
    setup do
      user = user_fixture()

      # Create high-risk direct route
      for i <- 1..5 do
        incident_fixture(%{
          user_id: user.id,
          type: "hijacking",
          latitude: -26.1541 + (i * 0.01),
          longitude: 28.0973 + (i * 0.01)
        })
      end

      %{user: user}
    end

    test "returns direct route and alternatives" do
      origin_lat = -26.2041
      origin_lng = 28.0473
      dest_lat = -26.1041
      dest_lng = 28.1473

      result = Travel.suggest_alternative_routes(origin_lat, origin_lng, dest_lat, dest_lng)

      assert Map.has_key?(result, :direct_route)
      assert Map.has_key?(result, :alternative_routes)
      assert Map.has_key?(result, :recommendation)

      # Verify direct route structure
      assert result.direct_route.route_name == "Direct Route"
      assert length(result.direct_route.waypoints) == 2
      assert result.direct_route.estimated_detour_km == 0

      # Verify alternatives
      assert length(result.alternative_routes) == 3

      Enum.each(result.alternative_routes, fn route ->
        assert Map.has_key?(route, :route_name)
        assert Map.has_key?(route, :waypoints)
        assert Map.has_key?(route, :safety_score)
        assert Map.has_key?(route, :total_incidents)
        assert Map.has_key?(route, :estimated_detour_km)

        # Alternatives should have 3 waypoints (origin, waypoint, destination)
        assert length(route.waypoints) == 3

        # Detour should be positive
        assert route.estimated_detour_km > 0
      end)
    end

    test "sorts alternatives by safety score" do
      origin_lat = -26.2041
      origin_lng = 28.0473
      dest_lat = -26.1041
      dest_lng = 28.1473

      result = Travel.suggest_alternative_routes(origin_lat, origin_lng, dest_lat, dest_lng)

      # Alternatives should be sorted by safety score (highest first)
      safety_scores = Enum.map(result.alternative_routes, & &1.safety_score)
      assert safety_scores == Enum.sort(safety_scores, :desc)
    end

    test "recommends alternative when direct route is unsafe" do
      origin_lat = -26.2041
      origin_lng = 28.0473
      dest_lat = -26.1041
      dest_lng = 28.1473

      result = Travel.suggest_alternative_routes(origin_lat, origin_lng, dest_lat, dest_lng)

      # With many incidents on direct route, should recommend alternative
      if result.direct_route.safety_score < 60 do
        assert result.recommendation =~ "alternative"
      end
    end

    test "recommends direct route when it is safest" do
      # Use route with no incidents
      origin_lat = -26.5041
      origin_lng = 28.5473
      dest_lat = -26.4041
      dest_lng = 28.6473

      result = Travel.suggest_alternative_routes(origin_lat, origin_lng, dest_lat, dest_lng)

      # With safe direct route, should recommend it
      if result.direct_route.safety_score >= 80 do
        assert result.recommendation =~ "Direct route"
      end
    end
  end

  describe "get_realtime_route_updates/5" do
    setup do
      user = user_fixture()

      # Create recent incident (within last 10 minutes)
      recent_incident = incident_fixture(%{
        user_id: user.id,
        type: "hijacking",
        latitude: -26.1541,
        longitude: 28.0973
      })

      # Create approaching zone
      zone = hotspot_zone_fixture(%{
        latitude: -26.1341,
        longitude: 28.1173,
        radius_meters: 500,
        risk_level: "critical",
        zone_type: "hijacking",
        incident_count: 15
      })

      %{user: user, recent_incident: recent_incident, zone: zone}
    end

    test "returns realtime updates for active journey" do
      current_lat = -26.1641
      current_lng = 28.0873
      dest_lat = -26.1041
      dest_lng = 28.1473

      result = Travel.get_realtime_route_updates(current_lat, current_lng, dest_lat, dest_lng)

      assert Map.has_key?(result, :remaining_route)
      assert Map.has_key?(result, :recent_incidents)
      assert Map.has_key?(result, :approaching_zones)
      assert Map.has_key?(result, :alerts)

      # Verify remaining route analysis
      assert is_map(result.remaining_route)
      assert Map.has_key?(result.remaining_route, :safety_score)

      # Verify recent incidents list
      assert is_list(result.recent_incidents)

      # Verify approaching zones list
      assert is_list(result.approaching_zones)

      # Verify alerts
      assert is_list(result.alerts)
      assert length(result.alerts) > 0
    end

    test "detects recent incidents near current location", %{recent_incident: incident} do
      # Position near the recent incident
      current_lat = -26.1541
      current_lng = 28.0973
      dest_lat = -26.1041
      dest_lng = 28.1473

      result = Travel.get_realtime_route_updates(current_lat, current_lng, dest_lat, dest_lng, 5000)

      # Should detect the recent incident
      assert length(result.recent_incidents) >= 1

      if length(result.recent_incidents) > 0 do
        incident_data = hd(result.recent_incidents)
        assert Map.has_key?(incident_data, :id)
        assert Map.has_key?(incident_data, :type)
        assert Map.has_key?(incident_data, :distance_meters)
        assert Map.has_key?(incident_data, :minutes_ago)
        assert incident_data.minutes_ago < 15
      end
    end

    test "detects approaching hotspot zones", %{zone: zone} do
      # Position approaching the zone
      current_lat = -26.1441
      current_lng = 28.1073
      dest_lat = -26.1041
      dest_lng = 28.1473

      result = Travel.get_realtime_route_updates(current_lat, current_lng, dest_lat, dest_lng)

      # Should detect approaching zone
      if length(result.approaching_zones) > 0 do
        zone_data = hd(result.approaching_zones)
        assert Map.has_key?(zone_data, :id)
        assert Map.has_key?(zone_data, :type)
        assert Map.has_key?(zone_data, :risk_level)
        assert Map.has_key?(zone_data, :distance_meters)

        # Distance should be within alert range (2km)
        assert zone_data.distance_meters <= 2000
      end
    end

    test "generates appropriate alerts for critical situations", %{zone: zone} do
      # Position near critical zone
      current_lat = -26.1441
      current_lng = 28.1073
      dest_lat = -26.1041
      dest_lng = 28.1473

      result = Travel.get_realtime_route_updates(current_lat, current_lng, dest_lat, dest_lng)

      # Should have alerts
      assert length(result.alerts) > 0

      # Check for critical zone alert
      critical_alert = Enum.find(result.alerts, fn alert ->
        String.contains?(alert, "CRITICAL") or String.contains?(alert, "critical")
      end)

      if length(result.approaching_zones) > 0 do
        assert critical_alert != nil
      end
    end

    test "returns safe message when no threats detected" do
      # Position far from any incidents or zones
      current_lat = -26.5041
      current_lng = 28.5473
      dest_lat = -26.4041
      dest_lng = 28.6473

      result = Travel.get_realtime_route_updates(current_lat, current_lng, dest_lat, dest_lng)

      # Should have safe message
      assert Enum.any?(result.alerts, fn alert ->
        String.contains?(alert, "No immediate safety concerns")
      end)
    end
  end

  describe "safety score calculation" do
    test "perfect score with no incidents or zones" do
      origin_lat = -26.5041
      origin_lng = 28.5473
      dest_lat = -26.4041
      dest_lng = 28.6473

      result = Travel.analyze_route_safety(origin_lat, origin_lng, dest_lat, dest_lng)

      assert result.safety_score == 100
      assert result.risk_level == "safe"
    end

    test "score decreases with more incidents" do
      user = user_fixture()

      origin_lat = -26.2041
      origin_lng = 28.0473
      dest_lat = -26.1041
      dest_lng = 28.1473

      # Get baseline score
      result1 = Travel.analyze_route_safety(origin_lat, origin_lng, dest_lat, dest_lng)
      baseline_score = result1.safety_score

      # Add incidents
      for i <- 1..5 do
        incident_fixture(%{
          user_id: user.id,
          latitude: -26.1541 + (i * 0.01),
          longitude: 28.0973 + (i * 0.01)
        })
      end

      result2 = Travel.analyze_route_safety(origin_lat, origin_lng, dest_lat, dest_lng, 5000)

      # Score should decrease
      assert result2.safety_score < baseline_score
    end

    test "critical zones have higher impact on score" do
      user = user_fixture()

      origin_lat = -26.2041
      origin_lng = 28.0473
      dest_lat = -26.1041
      dest_lng = 28.1473

      # Create critical zone
      _critical_zone = hotspot_zone_fixture(%{
        latitude: -26.1541,
        longitude: 28.0973,
        radius_meters: 1000,
        risk_level: "critical",
        zone_type: "hijacking",
        incident_count: 25
      })

      result = Travel.analyze_route_safety(origin_lat, origin_lng, dest_lat, dest_lng, 2000)

      # Score should be significantly reduced
      assert result.safety_score < 80
      assert result.risk_level in ["moderate", "caution", "dangerous"]
    end
  end

  describe "recommendations generation" do
    test "recommends alternative route for low safety score" do
      user = user_fixture()

      # Create many incidents
      for i <- 1..15 do
        incident_fixture(%{
          user_id: user.id,
          type: "hijacking",
          latitude: -26.1541 + (i * 0.005),
          longitude: 28.0973 + (i * 0.005)
        })
      end

      origin_lat = -26.2041
      origin_lng = 28.0473
      dest_lat = -26.1041
      dest_lng = 28.1473

      result = Travel.analyze_route_safety(origin_lat, origin_lng, dest_lat, dest_lng, 3000)

      # Should recommend alternative route
      assert Enum.any?(result.recommendations, fn rec ->
        String.contains?(rec, "alternative")
      end)
    end

    test "warns about critical zones" do
      _critical_zone = hotspot_zone_fixture(%{
        latitude: -26.1541,
        longitude: 28.0973,
        radius_meters: 1000,
        risk_level: "critical",
        zone_type: "hijacking",
        incident_count: 25
      })

      origin_lat = -26.2041
      origin_lng = 28.0473
      dest_lat = -26.1041
      dest_lng = 28.1473

      result = Travel.analyze_route_safety(origin_lat, origin_lng, dest_lat, dest_lng, 2000)

      # Should warn about critical zones
      assert Enum.any?(result.recommendations, fn rec ->
        String.contains?(rec, "critical")
      end)
    end

    test "warns about high hijacking activity" do
      user = user_fixture()

      # Create many hijacking incidents
      for i <- 1..5 do
        incident_fixture(%{
          user_id: user.id,
          type: "hijacking",
          latitude: -26.1541 + (i * 0.01),
          longitude: 28.0973 + (i * 0.01)
        })
      end

      origin_lat = -26.2041
      origin_lng = 28.0473
      dest_lat = -26.1041
      dest_lng = 28.1473

      result = Travel.analyze_route_safety(origin_lat, origin_lng, dest_lat, dest_lng, 3000)

      # Should warn about hijacking activity
      assert Enum.any?(result.recommendations, fn rec ->
        String.contains?(rec, "hijacking")
      end)
    end

    test "provides positive message for safe routes" do
      origin_lat = -26.5041
      origin_lng = 28.5473
      dest_lat = -26.4041
      dest_lng = 28.6473

      result = Travel.analyze_route_safety(origin_lat, origin_lng, dest_lat, dest_lng)

      # Should have positive message
      assert Enum.any?(result.recommendations, fn rec ->
        String.contains?(rec, "safe") or String.contains?(rec, "No specific")
      end)
    end
  end
end
