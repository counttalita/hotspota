defmodule HotspotApiWeb.EmergencyServicesControllerTest do
  use HotspotApiWeb.ConnCase

  import HotspotApi.AccountsFixtures

  alias HotspotApi.Guardian

  setup do
    user = user_fixture()
    {:ok, token, _claims} = Guardian.encode_and_sign(user, %{}, token_type: "access")

    %{user: user, token: token}
  end

  describe "GET /api/emergency-services/nearby" do
    test "returns nearby police stations and hospitals", %{conn: conn, token: token} do
      params = %{
        latitude: -26.2041,
        longitude: 28.0473,
        radius: 5000
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/emergency-services/nearby", params)

      assert %{
        "police_stations" => police_stations,
        "hospitals" => hospitals
      } = json_response(conn, 200)

      assert is_list(police_stations)
      assert is_list(hospitals)

      # Verify structure of police stations
      if length(police_stations) > 0 do
        station = hd(police_stations)
        assert Map.has_key?(station, "place_id")
        assert Map.has_key?(station, "name")
        assert Map.has_key?(station, "address")
        assert Map.has_key?(station, "location")
        assert Map.has_key?(station["location"], "latitude")
        assert Map.has_key?(station["location"], "longitude")
      end

      # Verify structure of hospitals
      if length(hospitals) > 0 do
        hospital = hd(hospitals)
        assert Map.has_key?(hospital, "place_id")
        assert Map.has_key?(hospital, "name")
        assert Map.has_key?(hospital, "address")
        assert Map.has_key?(hospital, "location")
      end
    end

    test "requires authentication", %{conn: conn} do
      params = %{
        latitude: -26.2041,
        longitude: 28.0473,
        radius: 5000
      }

      conn = get(conn, ~p"/api/emergency-services/nearby", params)

      assert json_response(conn, 401)
    end

    test "validates required parameters", %{conn: conn, token: token} do
      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/emergency-services/nearby")

      assert %{"error" => _message} = json_response(conn, 400)
    end

    test "uses default radius if not provided", %{conn: conn, token: token} do
      params = %{
        latitude: -26.2041,
        longitude: 28.0473
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/emergency-services/nearby", params)

      assert %{
        "police_stations" => _stations,
        "hospitals" => _hospitals
      } = json_response(conn, 200)
    end
  end

  describe "GET /api/emergency-services/police-stations" do
    test "returns only police stations", %{conn: conn, token: token} do
      params = %{
        latitude: -26.2041,
        longitude: 28.0473,
        radius: 5000
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/emergency-services/police-stations", params)

      assert %{"police_stations" => stations} = json_response(conn, 200)
      assert is_list(stations)

      if length(stations) > 0 do
        station = hd(stations)
        assert Map.has_key?(station, "name")
        assert Map.has_key?(station, "location")
      end
    end
  end

  describe "GET /api/emergency-services/hospitals" do
    test "returns only hospitals", %{conn: conn, token: token} do
      params = %{
        latitude: -26.2041,
        longitude: 28.0473,
        radius: 5000
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/emergency-services/hospitals", params)

      assert %{"hospitals" => hospitals} = json_response(conn, 200)
      assert is_list(hospitals)

      if length(hospitals) > 0 do
        hospital = hd(hospitals)
        assert Map.has_key?(hospital, "name")
        assert Map.has_key?(hospital, "location")
      end
    end
  end

  describe "POST /api/emergency-services/calculate-distance" do
    test "calculates distance and ETA to emergency service", %{conn: conn, token: token} do
      params = %{
        from_latitude: -26.2041,
        from_longitude: 28.0473,
        to_latitude: -25.7479,
        to_longitude: 28.2293
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/emergency-services/calculate-distance", params)

      assert %{
        "distance_meters" => distance_meters,
        "distance_text" => distance_text,
        "duration_seconds" => duration_seconds,
        "duration_text" => duration_text
      } = json_response(conn, 200)

      assert is_number(distance_meters)
      assert distance_meters > 0
      assert is_binary(distance_text)
      assert is_number(duration_seconds)
      assert duration_seconds > 0
      assert is_binary(duration_text)
    end

    test "formats short distances correctly", %{conn: conn, token: token} do
      # Very close points
      params = %{
        from_latitude: -26.2041,
        from_longitude: 28.0473,
        to_latitude: -26.2086,
        to_longitude: 28.0473
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/emergency-services/calculate-distance", params)

      assert %{
        "distance_meters" => distance_meters,
        "distance_text" => distance_text
      } = json_response(conn, 200)

      # Should be less than 1km
      assert distance_meters < 1000
      assert String.contains?(distance_text, "m")
      refute String.contains?(distance_text, "km")
    end

    test "formats long distances correctly", %{conn: conn, token: token} do
      # Far apart points
      params = %{
        from_latitude: -26.2041,
        from_longitude: 28.0473,
        to_latitude: -25.7479,
        to_longitude: 28.2293
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/emergency-services/calculate-distance", params)

      assert %{
        "distance_meters" => distance_meters,
        "distance_text" => distance_text
      } = json_response(conn, 200)

      # Should be more than 1km
      assert distance_meters > 1000
      assert String.contains?(distance_text, "km")
    end

    test "validates required parameters", %{conn: conn, token: token} do
      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/emergency-services/calculate-distance", %{})

      assert %{"error" => _message} = json_response(conn, 400)
    end
  end

  describe "caching behavior" do
    test "caches emergency services results", %{conn: conn, token: token} do
      params = %{
        latitude: -26.2041,
        longitude: 28.0473,
        radius: 5000
      }

      # First request
      conn1 = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/emergency-services/nearby", params)

      assert %{"police_stations" => stations1} = json_response(conn1, 200)

      # Second request (should be cached)
      conn2 = build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/emergency-services/nearby", params)

      assert %{"police_stations" => stations2} = json_response(conn2, 200)

      # Results should be the same
      assert length(stations1) == length(stations2)
    end
  end
end
