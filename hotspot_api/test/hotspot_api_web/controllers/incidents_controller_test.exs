defmodule HotspotApiWeb.IncidentsControllerTest do
  use HotspotApiWeb.ConnCase

  import HotspotApi.AccountsFixtures
  import HotspotApi.IncidentsFixtures

  alias HotspotApi.Guardian

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, user: user}
  end

  describe "POST /api/incidents" do
    test "creates incident with valid data", %{conn: conn} do
      incident_params = %{
        "incident" => %{
          "type" => "hijacking",
          "latitude" => -26.2041,
          "longitude" => 28.0473,
          "description" => "Test incident"
        }
      }

      conn = post(conn, ~p"/api/incidents", incident_params)
      assert %{"data" => incident} = json_response(conn, 201)
      assert incident["type"] == "hijacking"
      assert incident["description"] == "Test incident"
    end

    test "returns error with invalid incident type", %{conn: conn} do
      incident_params = %{
        "incident" => %{
          "type" => "invalid_type",
          "latitude" => -26.2041,
          "longitude" => 28.0473
        }
      }

      conn = post(conn, ~p"/api/incidents", incident_params)
      assert json_response(conn, 422)
    end

    test "rate limits incident creation", %{conn: conn} do
      incident_params = %{
        "incident" => %{
          "type" => "mugging",
          "latitude" => -26.2041,
          "longitude" => 28.0473
        }
      }

      # First request should succeed
      conn1 = post(conn, ~p"/api/incidents", incident_params)
      assert json_response(conn1, 201)

      # Second request within 1 minute should be rate limited
      conn2 = post(conn, ~p"/api/incidents", incident_params)
      assert json_response(conn2, 429)
    end
  end

  describe "GET /api/incidents/nearby" do
    test "returns nearby incidents", %{conn: conn, user: user} do
      # Create an incident
      {:ok, _incident} = HotspotApi.Incidents.create_incident(%{
        type: "accident",
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id
      })

      conn = get(conn, ~p"/api/incidents/nearby?lat=-26.2041&lng=28.0473&radius=5000")
      assert %{"data" => incidents} = json_response(conn, 200)
      assert length(incidents) == 1
      assert hd(incidents)["type"] == "accident"
    end

    test "returns empty list when no incidents nearby", %{conn: conn} do
      conn = get(conn, ~p"/api/incidents/nearby?lat=-26.2041&lng=28.0473&radius=100")
      assert %{"data" => incidents} = json_response(conn, 200)
      assert incidents == []
    end

    test "returns error with invalid coordinates", %{conn: conn} do
      conn = get(conn, ~p"/api/incidents/nearby?lat=invalid&lng=28.0473")
      assert json_response(conn, 400)
    end
  end

  describe "GET /api/incidents/feed" do
    test "returns paginated incident feed", %{conn: conn, user: user} do
      # Create multiple incidents
      for i <- 1..5 do
        HotspotApi.Incidents.create_incident(%{
          type: "mugging",
          latitude: -26.2041,
          longitude: 28.0473,
          description: "Incident #{i}",
          user_id: user.id
        })
      end

      conn = get(conn, ~p"/api/incidents/feed?lat=-26.2041&lng=28.0473&page=1&page_size=3")
      response = json_response(conn, 200)

      assert %{"incidents" => incidents, "pagination" => pagination} = response
      assert length(incidents) == 3
      assert pagination["total_count"] == 5
      assert pagination["page"] == 1
      assert pagination["page_size"] == 3
      assert pagination["total_pages"] == 2
    end

    test "filters incidents by type", %{conn: conn, user: user} do
      # Create different types
      HotspotApi.Incidents.create_incident(%{
        type: "hijacking",
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id
      })

      HotspotApi.Incidents.create_incident(%{
        type: "mugging",
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id
      })

      conn = get(conn, ~p"/api/incidents/feed?lat=-26.2041&lng=28.0473&type=hijacking")
      response = json_response(conn, 200)

      assert %{"incidents" => incidents} = response
      assert length(incidents) == 1
      assert hd(incidents)["type"] == "hijacking"
    end

    test "filters incidents by time range", %{conn: conn, user: user} do
      # Create a recent incident
      HotspotApi.Incidents.create_incident(%{
        type: "accident",
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id
      })

      conn = get(conn, ~p"/api/incidents/feed?lat=-26.2041&lng=28.0473&time_range=24h")
      response = json_response(conn, 200)

      assert %{"incidents" => incidents} = response
      assert length(incidents) == 1
    end

    test "includes distance in feed results", %{conn: conn, user: user} do
      HotspotApi.Incidents.create_incident(%{
        type: "mugging",
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id
      })

      conn = get(conn, ~p"/api/incidents/feed?lat=-26.2041&lng=28.0473")
      response = json_response(conn, 200)

      assert %{"incidents" => incidents} = response
      assert length(incidents) == 1
      incident = hd(incidents)
      assert Map.has_key?(incident, "distance")
      assert is_number(incident["distance"])
    end

    test "returns error with invalid coordinates", %{conn: conn} do
      conn = get(conn, ~p"/api/incidents/feed?lat=invalid&lng=28.0473")
      assert json_response(conn, 400)
    end
  end
end
