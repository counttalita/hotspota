defmodule HotspotApiWeb.AnalyticsControllerTest do
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

  describe "GET /api/analytics/summary" do
    test "returns analytics summary", %{conn: conn} do
      # Create some test incidents
      incident_fixture(%{type: "hijacking"})
      incident_fixture(%{type: "mugging"})

      conn = get(conn, ~p"/api/analytics/summary")
      assert %{"data" => summary} = json_response(conn, 200)
      assert is_integer(summary["total_incidents"])
      assert is_integer(summary["active_incidents"])
      assert is_float(summary["verification_rate"])
    end
  end

  describe "GET /api/analytics/time-patterns" do
    test "returns time pattern analysis", %{conn: conn} do
      conn = get(conn, ~p"/api/analytics/time-patterns")
      assert %{"data" => patterns} = json_response(conn, 200)
      assert is_list(patterns)
    end
  end

  describe "GET /api/analytics/trends" do
    test "returns weekly trends with default weeks", %{conn: conn} do
      conn = get(conn, ~p"/api/analytics/trends")
      assert %{"data" => trends} = json_response(conn, 200)
      assert is_list(trends)
    end

    test "returns weekly trends with custom weeks parameter", %{conn: conn} do
      conn = get(conn, ~p"/api/analytics/trends?weeks=8")
      assert %{"data" => trends} = json_response(conn, 200)
      assert is_list(trends)
    end
  end

  describe "GET /api/analytics/hotspots" do
    test "returns 403 for non-premium users", %{conn: conn} do
      conn = get(conn, ~p"/api/analytics/hotspots")
      assert %{"error" => "Premium subscription required"} = json_response(conn, 403)
    end

    test "returns hotspots for premium users", %{conn: conn, user: user} do
      # Update user to premium
      HotspotApi.Accounts.update_user(user, %{is_premium: true})

      # Create some test incidents in clusters
      incident_fixture(%{type: "hijacking", latitude: -26.2041, longitude: 28.0473})
      incident_fixture(%{type: "hijacking", latitude: -26.2042, longitude: 28.0474})
      incident_fixture(%{type: "hijacking", latitude: -26.2043, longitude: 28.0475})

      conn = get(conn, ~p"/api/analytics/hotspots")
      assert %{"data" => hotspots} = json_response(conn, 200)
      assert is_list(hotspots)
    end
  end
end
