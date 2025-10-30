defmodule HotspotApiWeb.NotificationsControllerTest do
  use HotspotApiWeb.ConnCase

  alias HotspotApi.Accounts
  alias HotspotApi.Guardian

  setup %{conn: conn} do
    # Create a test user
    {:ok, user} = Accounts.create_user(%{
      phone_number: "+27123456789",
      is_premium: false,
      alert_radius: 2000,
      notification_config: %{
        "enabled_types" => %{
          "hijacking" => true,
          "mugging" => true,
          "accident" => true
        }
      }
    })

    # Generate JWT token
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn = conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, user: user}
  end

  describe "GET /api/notifications/preferences" do
    test "returns user notification preferences", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/notifications/preferences")

      assert %{
        "success" => true,
        "data" => %{
          "alert_radius" => 2000,
          "is_premium" => false,
          "notification_config" => notification_config
        }
      } = json_response(conn, 200)

      assert notification_config["enabled_types"]["hijacking"] == true
    end
  end

  describe "PUT /api/notifications/preferences" do
    test "updates notification preferences for free user", %{conn: conn} do
      params = %{
        "alert_radius" => 1500,
        "notification_config" => %{
          "enabled_types" => %{
            "hijacking" => true,
            "mugging" => false,
            "accident" => true
          }
        }
      }

      conn = put(conn, ~p"/api/notifications/preferences", params)

      assert %{
        "success" => true,
        "message" => "Preferences updated successfully",
        "data" => %{
          "alert_radius" => 1500,
          "notification_config" => notification_config
        }
      } = json_response(conn, 200)

      assert notification_config["enabled_types"]["mugging"] == false
    end

    test "enforces 2km radius limit for free users", %{conn: conn} do
      params = %{
        "alert_radius" => 5000  # Try to set 5km
      }

      conn = put(conn, ~p"/api/notifications/preferences", params)

      response = json_response(conn, 200)

      # Should be capped at 2000 for free users
      assert response["data"]["alert_radius"] == 2000
    end

    test "allows up to 10km radius for premium users", %{conn: conn, user: user} do
      # Upgrade user to premium
      {:ok, _premium_user} = Accounts.update_user(user, %{is_premium: true})

      params = %{
        "alert_radius" => 8000  # Set 8km
      }

      conn = put(conn, ~p"/api/notifications/preferences", params)

      response = json_response(conn, 200)

      # Should allow 8km for premium users
      assert response["data"]["alert_radius"] == 8000
    end

    test "enforces 10km radius limit even for premium users", %{conn: conn, user: user} do
      # Upgrade user to premium
      {:ok, _premium_user} = Accounts.update_user(user, %{is_premium: true})

      params = %{
        "alert_radius" => 15000  # Try to set 15km
      }

      conn = put(conn, ~p"/api/notifications/preferences", params)

      response = json_response(conn, 200)

      # Should be capped at 10000 even for premium users
      assert response["data"]["alert_radius"] == 10000
    end
  end
end
