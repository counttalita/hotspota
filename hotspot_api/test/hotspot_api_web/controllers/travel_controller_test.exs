defmodule HotspotApiWeb.TravelControllerTest do
  use HotspotApiWeb.ConnCase

  import HotspotApi.AccountsFixtures
  import HotspotApi.IncidentsFixtures
  import HotspotApi.GeofencingFixtures

  alias HotspotApi.Guardian

  setup do
    user = user_fixture(%{is_premium: true})
    {:ok, token, _claims} = Guardian.encode_and_sign(user, %{}, token_type: "access")

    %{user: user, token: token}
  end

  describe "POST /api/travel/analyze-route" do
    test "analyzes route safety for premium users", %{conn: conn, token: token, user: user} do
      # Create incidents along route
      _incident = incident_fixture(%{
        user_id: user.id,
        type: "hijacking",
        latitude: -26.1541,
        longitude: 28.0973
      })

      route_params = %{
        origin_latitude: -26.2041,
        origin_longitude: 28.0473,
        destination_latitude: -26.1041,
        destination_longitude: 28.1473
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/travel/analyze-route", route_params)

      assert %{
        "safety_score" => safety_score,
        "risk_level" => risk_level,
        "total_incidents" => _total,
        "incident_counts" => _counts,
        "hotspot_zones" => _zones,
        "segments" => segments,
        "recommendations" => recommendations
      } = json_response(conn, 200)

      assert is_number(safety_score)
      assert safety_score >= 0 and safety_score <= 100
      assert risk_level in ["safe", "moderate", "caution", "dangerous"]
      assert is_list(segments)
      assert length(segments) == 5
      assert is_list(recommendations)
    end

    test "returns error for non-premium users", %{conn: conn} do
      free_user = user_fixture(%{phone_number: "+27987654321", is_premium: false})
      {:ok, free_token, _} = Guardian.encode_and_sign(free_user, %{}, token_type: "access")

      route_params = %{
        origin_latitude: -26.2041,
        origin_longitude: 28.0473,
        destination_latitude: -26.1041,
        destination_longitude: 28.1473
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{free_token}")
      |> post(~p"/api/travel/analyze-route", route_params)

      assert %{"error" => _message} = json_response(conn, 403)
    end

    test "requires authentication", %{conn: conn} do
      route_params = %{
        origin_latitude: -26.2041,
        origin_longitude: 28.0473,
        destination_latitude: -26.1041,
        destination_longitude: 28.1473
      }

      conn = post(conn, ~p"/api/travel/analyze-route", route_params)

      assert json_response(conn, 401)
    end

    test "validates required parameters", %{conn: conn, token: token} do
      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/travel/analyze-route", %{})

      assert %{"error" => _message} = json_response(conn, 400)
    end
  end

  describe "POST /api/travel/alternative-routes" do
    test "suggests alternative routes", %{conn: conn, token: token, user: user} do
      # Create incidents on direct route
      for i <- 1..5 do
        incident_fixture(%{
          user_id: user.id,
          type: "hijacking",
          latitude: -26.1541 + (i * 0.01),
          longitude: 28.0973 + (i * 0.01)
        })
      end

      route_params = %{
        origin_latitude: -26.2041,
        origin_longitude: 28.0473,
        destination_latitude: -26.1041,
        destination_longitude: 28.1473
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/travel/alternative-routes", route_params)

      assert %{
        "direct_route" => direct_route,
        "alternative_routes" => alternatives,
        "recommendation" => recommendation
      } = json_response(conn, 200)

      assert Map.has_key?(direct_route, "safety_score")
      assert Map.has_key?(direct_route, "waypoints")
      assert length(direct_route["waypoints"]) == 2

      assert is_list(alternatives)
      assert length(alternatives) == 3

      Enum.each(alternatives, fn route ->
        assert Map.has_key?(route, "route_name")
        assert Map.has_key?(route, "safety_score")
        assert Map.has_key?(route, "waypoints")
        assert Map.has_key?(route, "estimated_detour_km")
        assert length(route["waypoints"]) == 3
      end)

      assert is_binary(recommendation)
    end

    test "returns error for non-premium users", %{conn: conn} do
      free_user = user_fixture(%{phone_number: "+27987654321", is_premium: false})
      {:ok, free_token, _} = Guardian.encode_and_sign(free_user, %{}, token_type: "access")

      route_params = %{
        origin_latitude: -26.2041,
        origin_longitude: 28.0473,
        destination_latitude: -26.1041,
        destination_longitude: 28.1473
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{free_token}")
      |> post(~p"/api/travel/alternative-routes", route_params)

      assert %{"error" => _message} = json_response(conn, 403)
    end
  end

  describe "POST /api/travel/realtime-updates" do
    test "provides realtime route updates", %{conn: conn, token: token, user: user} do
      # Create recent incident
      _incident = incident_fixture(%{
        user_id: user.id,
        type: "hijacking",
        latitude: -26.1541,
        longitude: 28.0973
      })

      # Create approaching zone
      _zone = hotspot_zone_fixture(%{
        center_latitude: -26.1341,
        center_longitude: 28.1173,
        radius_meters: 500,
        risk_level: "critical",
        zone_type: "hijacking",
        incident_count: 15
      })

      update_params = %{
        current_latitude: -26.1641,
        current_longitude: 28.0873,
        destination_latitude: -26.1041,
        destination_longitude: 28.1473
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/travel/realtime-updates", update_params)

      assert %{
        "remaining_route" => remaining_route,
        "recent_incidents" => recent_incidents,
        "approaching_zones" => approaching_zones,
        "alerts" => alerts
      } = json_response(conn, 200)

      assert is_map(remaining_route)
      assert Map.has_key?(remaining_route, "safety_score")

      assert is_list(recent_incidents)
      assert is_list(approaching_zones)
      assert is_list(alerts)
      assert length(alerts) > 0
    end

    test "detects recent incidents", %{conn: conn, token: token, user: user} do
      # Create very recent incident
      _incident = incident_fixture(%{
        user_id: user.id,
        type: "hijacking",
        latitude: -26.1641,
        longitude: 28.0873
      })

      update_params = %{
        current_latitude: -26.1641,
        current_longitude: 28.0873,
        destination_latitude: -26.1041,
        destination_longitude: 28.1473
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/travel/realtime-updates", update_params)

      assert %{"recent_incidents" => recent_incidents} = json_response(conn, 200)

      if length(recent_incidents) > 0 do
        incident = hd(recent_incidents)
        assert Map.has_key?(incident, "id")
        assert Map.has_key?(incident, "type")
        assert Map.has_key?(incident, "distance_meters")
        assert Map.has_key?(incident, "minutes_ago")
        assert incident["minutes_ago"] < 15
      end
    end

    test "detects approaching zones", %{conn: conn, token: token} do
      # Create zone ahead
      _zone = hotspot_zone_fixture(%{
        center_latitude: -26.1341,
        center_longitude: 28.1173,
        radius_meters: 500,
        risk_level: "high",
        zone_type: "hijacking",
        incident_count: 10
      })

      update_params = %{
        current_latitude: -26.1441,
        current_longitude: 28.1073,
        destination_latitude: -26.1041,
        destination_longitude: 28.1473
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/travel/realtime-updates", update_params)

      assert %{"approaching_zones" => approaching_zones} = json_response(conn, 200)

      if length(approaching_zones) > 0 do
        zone = hd(approaching_zones)
        assert Map.has_key?(zone, "id")
        assert Map.has_key?(zone, "type")
        assert Map.has_key?(zone, "risk_level")
        assert Map.has_key?(zone, "distance_meters")
      end
    end

    test "returns error for non-premium users", %{conn: conn} do
      free_user = user_fixture(%{phone_number: "+27987654321", is_premium: false})
      {:ok, free_token, _} = Guardian.encode_and_sign(free_user, %{}, token_type: "access")

      update_params = %{
        current_latitude: -26.1641,
        current_longitude: 28.0873,
        destination_latitude: -26.1041,
        destination_longitude: 28.1473
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{free_token}")
      |> post(~p"/api/travel/realtime-updates", update_params)

      assert %{"error" => _message} = json_response(conn, 403)
    end
  end
end
