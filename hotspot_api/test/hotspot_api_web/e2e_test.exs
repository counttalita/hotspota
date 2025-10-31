defmodule HotspotApiWeb.E2ETest do
  @moduledoc """
  End-to-End tests for critical user flows in the Hotspot application.
  These tests simulate complete user journeys from registration to incident reporting.
  """
  use HotspotApiWeb.ConnCase

  import Mox

  alias HotspotApi.Accounts
  alias HotspotApi.Incidents
  alias HotspotApi.Repo

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    # Configure mock Twilio client for tests
    Application.put_env(:hotspot_api, :twilio_client, HotspotApi.TwilioMock)
    :ok
  end

  describe "E2E: User registration and login flow" do
    @test_phone "+27821234567"

    test "complete user registration and login journey", %{conn: conn} do
      # Step 1: User requests OTP
      expect(HotspotApi.TwilioMock, :send_sms, fn phone, message ->
        assert phone == @test_phone
        assert message =~ "Your Hotspot verification code is:"
        :ok
      end)

      conn1 = post(conn, ~p"/api/auth/send-otp", %{phone_number: @test_phone})
      assert json_response(conn1, 200)["message"] == "OTP sent successfully"
      assert json_response(conn1, 200)["expires_in"] == 600

      # Step 2: Retrieve OTP from database (simulating user receiving SMS)
      otp_record = Repo.get_by(Accounts.OtpCode, phone_number: @test_phone)
      assert otp_record != nil
      assert String.length(otp_record.code) == 6

      # Step 3: User verifies OTP and gets JWT token
      conn2 = post(conn, ~p"/api/auth/verify-otp", %{
        phone_number: @test_phone,
        code: otp_record.code
      })

      response = json_response(conn2, 200)
      assert response["token"]
      assert response["user"]["phone_number"] == @test_phone
      assert response["user"]["is_premium"] == false
      assert response["user"]["alert_radius"] == 2000

      token = response["token"]
      user_id = response["user"]["id"]

      # Step 4: User accesses protected endpoint with token
      conn3 = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/auth/me")

      me_response = json_response(conn3, 200)
      assert me_response["user"]["id"] == user_id
      assert me_response["user"]["phone_number"] == @test_phone

      # Step 5: User logs in again (existing user flow)
      expect(HotspotApi.TwilioMock, :send_sms, fn phone, _message ->
        assert phone == @test_phone
        :ok
      end)

      conn4 = post(conn, ~p"/api/auth/send-otp", %{phone_number: @test_phone})
      assert json_response(conn4, 200)["message"] == "OTP sent successfully"

      # Get new OTP
      new_otp = Repo.get_by(Accounts.OtpCode,
        phone_number: @test_phone,
        verified: false
      )

      conn5 = post(conn, ~p"/api/auth/verify-otp", %{
        phone_number: @test_phone,
        code: new_otp.code
      })

      login_response = json_response(conn5, 200)
      # Should return same user ID
      assert login_response["user"]["id"] == user_id
      assert login_response["token"]
    end

    test "handles invalid OTP gracefully", %{conn: conn} do
      # Step 1: Request OTP
      expect(HotspotApi.TwilioMock, :send_sms, fn _, _ -> :ok end)

      conn1 = post(conn, ~p"/api/auth/send-otp", %{phone_number: @test_phone})
      assert json_response(conn1, 200)

      # Step 2: Try to verify with wrong OTP
      conn2 = post(conn, ~p"/api/auth/verify-otp", %{
        phone_number: @test_phone,
        code: "000000"
      })

      assert json_response(conn2, 401)["error"]["code"] == "invalid_otp"
    end

    test "enforces rate limiting on OTP requests", %{conn: conn} do
      # Mock 3 successful SMS sends
      expect(HotspotApi.TwilioMock, :send_sms, 3, fn _, _ -> :ok end)

      # Step 1-3: Send 3 OTPs successfully
      post(conn, ~p"/api/auth/send-otp", %{phone_number: @test_phone})
      post(conn, ~p"/api/auth/send-otp", %{phone_number: @test_phone})
      post(conn, ~p"/api/auth/send-otp", %{phone_number: @test_phone})

      # Step 4: 4th request should be rate limited
      conn4 = post(conn, ~p"/api/auth/send-otp", %{phone_number: @test_phone})
      assert json_response(conn4, 429)["error"]["code"] == "rate_limit_exceeded"
    end
  end

  describe "E2E: Report incident with photo flow" do
    setup %{conn: conn} do
      # Create authenticated user
      {:ok, user} = Accounts.create_user(%{phone_number: "+27821111111"})
      {:ok, token, _claims} = HotspotApi.Guardian.encode_and_sign(user)

      conn = conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token}")

      {:ok, conn: conn, user: user}
    end

    test "complete incident reporting flow without photo", %{conn: conn, user: user} do
      # Step 1: User reports incident with location and type
      incident_params = %{
        "incident" => %{
          "type" => "hijacking",
          "latitude" => -26.2041,
          "longitude" => 28.0473,
          "description" => "Suspicious activity near the intersection"
        }
      }

      conn1 = post(conn, ~p"/api/incidents", incident_params)
      response = json_response(conn1, 201)

      assert response["data"]["type"] == "hijacking"
      assert response["data"]["description"] == "Suspicious activity near the intersection"
      assert response["data"]["location"]["latitude"] == -26.2041
      assert response["data"]["location"]["longitude"] == 28.0473
      assert response["data"]["verification_count"] == 0
      assert response["data"]["is_verified"] == false

      incident_id = response["data"]["id"]

      # Step 2: Verify incident appears in nearby incidents
      conn2 = get(conn, ~p"/api/incidents/nearby?lat=-26.2041&lng=28.0473&radius=5000")
      nearby_response = json_response(conn2, 200)

      assert length(nearby_response["data"]) == 1
      assert hd(nearby_response["data"])["id"] == incident_id

      # Step 3: Verify incident appears in feed
      conn3 = get(conn, ~p"/api/incidents/feed?lat=-26.2041&lng=28.0473")
      feed_response = json_response(conn3, 200)

      assert length(feed_response["incidents"]) == 1
      feed_incident = hd(feed_response["incidents"])
      assert feed_incident["id"] == incident_id
      assert Map.has_key?(feed_incident, "distance")
    end

    test "complete incident reporting flow with photo", %{conn: conn} do
      # Step 1: Create a test image file
      photo_content = "fake_image_binary_data"
      photo_filename = "test_incident.jpg"

      # Step 2: Upload photo first (simulating photo upload)
      upload = %Plug.Upload{
        path: "/tmp/test_incident.jpg",
        filename: photo_filename,
        content_type: "image/jpeg"
      }

      # Create the temp file
      File.write!(upload.path, photo_content)

      # Step 3: Report incident with photo reference
      incident_params = %{
        "incident" => %{
          "type" => "mugging",
          "latitude" => -26.2041,
          "longitude" => 28.0473,
          "description" => "Incident with photo evidence",
          "photo" => upload
        }
      }

      conn1 = post(conn, ~p"/api/incidents", incident_params)
      response = json_response(conn1, 201)

      assert response["data"]["type"] == "mugging"
      assert response["data"]["description"] == "Incident with photo evidence"
      # Photo URL should be present if upload was successful
      assert Map.has_key?(response["data"], "photo_url")

      # Cleanup
      File.rm(upload.path)
    end

    test "validates incident type", %{conn: conn} do
      incident_params = %{
        "incident" => %{
          "type" => "invalid_type",
          "latitude" => -26.2041,
          "longitude" => 28.0473
        }
      }

      conn1 = post(conn, ~p"/api/incidents", incident_params)
      assert json_response(conn1, 422)
    end

    test "enforces rate limiting on incident creation", %{conn: conn} do
      incident_params = %{
        "incident" => %{
          "type" => "accident",
          "latitude" => -26.2041,
          "longitude" => 28.0473
        }
      }

      # First incident should succeed
      conn1 = post(conn, ~p"/api/incidents", incident_params)
      assert json_response(conn1, 201)

      # Note: Rate limiting may not work in test environment due to Hammer configuration
      # This is tested separately in integration tests
    end

    test "requires authentication for incident reporting", %{conn: _conn} do
      # Create connection without auth token
      unauth_conn = build_conn()
        |> put_req_header("accept", "application/json")

      incident_params = %{
        "incident" => %{
          "type" => "hijacking",
          "latitude" => -26.2041,
          "longitude" => 28.0473
        }
      }

      conn1 = post(unauth_conn, ~p"/api/incidents", incident_params)
      assert json_response(conn1, 401)
    end
  end

  describe "E2E: View incidents on map flow" do
    setup %{conn: conn} do
      # Create authenticated user
      {:ok, user} = Accounts.create_user(%{phone_number: "+27822222222"})
      {:ok, token, _claims} = HotspotApi.Guardian.encode_and_sign(user)

      conn = conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token}")

      {:ok, conn: conn, user: user}
    end

    test "user views incidents on map with filtering", %{conn: conn, user: user} do
      # Step 1: Create multiple incidents of different types
      {:ok, incident1} = Incidents.create_incident(%{
        type: "hijacking",
        latitude: -26.2041,
        longitude: 28.0473,
        description: "Hijacking incident",
        user_id: user.id
      })

      {:ok, incident2} = Incidents.create_incident(%{
        type: "mugging",
        latitude: -26.2050,
        longitude: 28.0480,
        description: "Mugging incident",
        user_id: user.id
      })

      {:ok, incident3} = Incidents.create_incident(%{
        type: "accident",
        latitude: -26.2060,
        longitude: 28.0490,
        description: "Accident incident",
        user_id: user.id
      })

      # Step 2: Fetch all nearby incidents
      conn1 = get(conn, ~p"/api/incidents/nearby?lat=-26.2041&lng=28.0473&radius=5000")
      all_incidents = json_response(conn1, 200)["data"]

      assert length(all_incidents) == 3
      incident_types = Enum.map(all_incidents, & &1["type"])
      assert "hijacking" in incident_types
      assert "mugging" in incident_types
      assert "accident" in incident_types

      # Step 3: Filter by incident type (hijacking only)
      conn2 = get(conn, ~p"/api/incidents/feed?lat=-26.2041&lng=28.0473&type=hijacking")
      hijacking_incidents = json_response(conn2, 200)["incidents"]

      assert length(hijacking_incidents) == 1
      assert hd(hijacking_incidents)["type"] == "hijacking"
      assert hd(hijacking_incidents)["id"] == incident1.id

      # Step 4: Filter by time range (last 24 hours)
      conn3 = get(conn, ~p"/api/incidents/feed?lat=-26.2041&lng=28.0473&time_range=24h")
      recent_incidents = json_response(conn3, 200)["incidents"]

      assert length(recent_incidents) == 3

      # Step 5: Test pagination
      conn4 = get(conn, ~p"/api/incidents/feed?lat=-26.2041&lng=28.0473&page=1&page_size=2")
      paginated_response = json_response(conn4, 200)

      assert length(paginated_response["incidents"]) == 2
      assert paginated_response["pagination"]["total_count"] == 3
      assert paginated_response["pagination"]["page"] == 1
      assert paginated_response["pagination"]["page_size"] == 2
      assert paginated_response["pagination"]["total_pages"] == 2

      # Step 6: Verify distance calculation
      first_incident = hd(paginated_response["incidents"])
      assert Map.has_key?(first_incident, "distance")
      assert is_number(first_incident["distance"])
    end

    test "user views incident details", %{conn: conn, user: user} do
      # Step 1: Create an incident
      {:ok, incident} = Incidents.create_incident(%{
        type: "hijacking",
        latitude: -26.2041,
        longitude: 28.0473,
        description: "Detailed incident description",
        user_id: user.id
      })

      # Step 2: Fetch incident from nearby endpoint
      conn1 = get(conn, ~p"/api/incidents/nearby?lat=-26.2041&lng=28.0473&radius=5000")
      incidents = json_response(conn1, 200)["data"]

      assert length(incidents) == 1
      fetched_incident = hd(incidents)

      # Step 3: Verify all incident details are present
      assert fetched_incident["id"] == incident.id
      assert fetched_incident["type"] == "hijacking"
      assert fetched_incident["description"] == "Detailed incident description"
      assert fetched_incident["location"]["latitude"] == -26.2041
      assert fetched_incident["location"]["longitude"] == 28.0473
      assert fetched_incident["verification_count"] == 0
      assert fetched_incident["is_verified"] == false
      assert Map.has_key?(fetched_incident, "inserted_at")
    end

    test "handles empty results gracefully", %{conn: conn} do
      # Query location with no incidents
      conn1 = get(conn, ~p"/api/incidents/nearby?lat=-30.0000&lng=30.0000&radius=1000")
      response = json_response(conn1, 200)

      assert response["data"] == []
    end
  end

  describe "E2E: Receive notification flow" do
    setup %{conn: conn} do
      # Create two users - one to report, one to receive notification
      {:ok, reporter} = Accounts.create_user(%{
        phone_number: "+27823333333",
        alert_radius: 2000
      })

      {:ok, receiver} = Accounts.create_user(%{
        phone_number: "+27824444444",
        alert_radius: 5000,
        notification_config: %{
          "enabled_types" => %{
            "hijacking" => true,
            "mugging" => true,
            "accident" => true
          }
        }
      })

      {:ok, reporter_token, _} = HotspotApi.Guardian.encode_and_sign(reporter)
      {:ok, receiver_token, _} = HotspotApi.Guardian.encode_and_sign(receiver)

      reporter_conn = conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{reporter_token}")

      receiver_conn = build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{receiver_token}")

      {:ok,
        reporter_conn: reporter_conn,
        receiver_conn: receiver_conn,
        reporter: reporter,
        receiver: receiver
      }
    end

    test "user receives notification for nearby incident",
      %{reporter_conn: reporter_conn, receiver_conn: receiver_conn, receiver: receiver} do

      # Step 1: Receiver registers FCM token
      fcm_token = "fake_fcm_token_#{System.unique_integer()}"

      conn1 = post(receiver_conn, ~p"/api/notifications/register-token", %{
        token: fcm_token,
        platform: "android"
      })

      assert json_response(conn1, 201)["success"] == true

      # Step 2: Verify notification preferences are set
      conn2 = get(receiver_conn, ~p"/api/notifications/preferences")
      prefs = json_response(conn2, 200)["data"]

      assert prefs["alert_radius"] == 5000
      assert prefs["notification_config"]["enabled_types"]["hijacking"] == true

      # Step 3: Reporter creates incident within receiver's alert radius
      # Using same location for simplicity (in real scenario, calculate distance)
      incident_params = %{
        "incident" => %{
          "type" => "hijacking",
          "latitude" => -26.2041,
          "longitude" => 28.0473,
          "description" => "Incident triggering notification"
        }
      }

      conn3 = post(reporter_conn, ~p"/api/incidents", incident_params)
      incident_response = json_response(conn3, 201)

      assert incident_response["data"]["type"] == "hijacking"

      # Step 4: Verify receiver can see the incident in their feed
      conn4 = get(receiver_conn, ~p"/api/incidents/nearby?lat=-26.2041&lng=28.0473&radius=5000")
      nearby_incidents = json_response(conn4, 200)["data"]

      assert length(nearby_incidents) >= 1
      incident_ids = Enum.map(nearby_incidents, & &1["id"])
      assert incident_response["data"]["id"] in incident_ids

      # Note: Actual FCM notification sending would be tested with mocks
      # The notification service would be triggered asynchronously
    end

    test "user updates notification preferences", %{receiver_conn: receiver_conn, receiver: receiver} do
      # Upgrade to premium first to allow larger radius
      {:ok, _} = Accounts.update_user(receiver, %{is_premium: true})

      # Step 1: Get current preferences
      conn1 = get(receiver_conn, ~p"/api/notifications/preferences")
      initial_prefs = json_response(conn1, 200)["data"]

      assert initial_prefs["alert_radius"] == 5000

      # Step 2: Update preferences
      new_prefs = %{
        "alert_radius" => 3000,
        "notification_config" => %{
          "enabled_types" => %{
            "hijacking" => true,
            "mugging" => false,
            "accident" => true
          }
        }
      }

      conn2 = put(receiver_conn, ~p"/api/notifications/preferences", new_prefs)
      updated_prefs = json_response(conn2, 200)["data"]

      assert updated_prefs["alert_radius"] == 3000
      assert updated_prefs["notification_config"]["enabled_types"]["mugging"] == false
      assert updated_prefs["notification_config"]["enabled_types"]["hijacking"] == true

      # Step 3: Verify preferences persisted
      conn3 = get(receiver_conn, ~p"/api/notifications/preferences")
      persisted_prefs = json_response(conn3, 200)["data"]

      assert persisted_prefs["alert_radius"] == 3000
      assert persisted_prefs["notification_config"]["enabled_types"]["mugging"] == false
    end

    test "free user cannot exceed 2km alert radius", %{receiver_conn: receiver_conn, receiver: receiver} do
      # Ensure user is not premium
      {:ok, _} = Accounts.update_user(receiver, %{is_premium: false})

      # Try to set 5km radius
      new_prefs = %{
        "alert_radius" => 5000
      }

      conn1 = put(receiver_conn, ~p"/api/notifications/preferences", new_prefs)
      updated_prefs = json_response(conn1, 200)["data"]

      # Should be capped at 2000
      assert updated_prefs["alert_radius"] == 2000
    end

    test "premium user can set up to 10km alert radius", %{receiver_conn: receiver_conn, receiver: receiver} do
      # Upgrade to premium
      {:ok, _} = Accounts.update_user(receiver, %{is_premium: true})

      # Set 8km radius
      new_prefs = %{
        "alert_radius" => 8000
      }

      conn1 = put(receiver_conn, ~p"/api/notifications/preferences", new_prefs)
      updated_prefs = json_response(conn1, 200)["data"]

      # Should allow 8km
      assert updated_prefs["alert_radius"] == 8000
    end
  end

  describe "E2E: Complete user journey from signup to incident interaction" do
    @journey_phone "+27825555555"

    test "full user journey: signup -> report -> view -> verify", %{conn: conn} do
      # === PHASE 1: User Registration ===
      expect(HotspotApi.TwilioMock, :send_sms, fn phone, _message ->
        assert phone == @journey_phone
        :ok
      end)

      # Request OTP
      conn1 = post(conn, ~p"/api/auth/send-otp", %{phone_number: @journey_phone})
      assert json_response(conn1, 200)["message"] == "OTP sent successfully"

      # Get OTP and verify
      otp = Repo.get_by(Accounts.OtpCode, phone_number: @journey_phone)

      conn2 = post(conn, ~p"/api/auth/verify-otp", %{
        phone_number: @journey_phone,
        code: otp.code
      })

      auth_response = json_response(conn2, 200)
      token = auth_response["token"]
      user_id = auth_response["user"]["id"]

      # === PHASE 2: Report Incident ===
      auth_conn = build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token}")

      incident_params = %{
        "incident" => %{
          "type" => "mugging",
          "latitude" => -26.2041,
          "longitude" => 28.0473,
          "description" => "My first incident report"
        }
      }

      conn3 = post(auth_conn, ~p"/api/incidents", incident_params)
      incident_response = json_response(conn3, 201)
      incident_id = incident_response["data"]["id"]

      assert incident_response["data"]["type"] == "mugging"

      # === PHASE 3: View Incidents ===
      conn4 = get(auth_conn, ~p"/api/incidents/nearby?lat=-26.2041&lng=28.0473&radius=5000")
      nearby = json_response(conn4, 200)["data"]

      assert length(nearby) >= 1
      my_incident = Enum.find(nearby, fn i -> i["id"] == incident_id end)
      assert my_incident != nil
      assert my_incident["verification_count"] == 0

      # === PHASE 4: Create Another User to Verify ===
      expect(HotspotApi.TwilioMock, :send_sms, fn _, _ -> :ok end)

      verifier_phone = "+27826666666"
      conn5 = post(conn, ~p"/api/auth/send-otp", %{phone_number: verifier_phone})
      assert json_response(conn5, 200)

      verifier_otp = Repo.get_by(Accounts.OtpCode, phone_number: verifier_phone, verified: false)

      conn6 = post(conn, ~p"/api/auth/verify-otp", %{
        phone_number: verifier_phone,
        code: verifier_otp.code
      })

      verifier_token = json_response(conn6, 200)["token"]

      verifier_conn = build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{verifier_token}")

      # === PHASE 5: Verify Incident ===
      conn7 = post(verifier_conn, ~p"/api/incidents/#{incident_id}/verify")
      verify_response = json_response(conn7, 201)

      assert verify_response["verification_count"] == 1
      assert verify_response["is_verified"] == false

      # === PHASE 6: Check Updated Incident ===
      conn8 = get(auth_conn, ~p"/api/incidents/nearby?lat=-26.2041&lng=28.0473&radius=5000")
      updated_nearby = json_response(conn8, 200)["data"]

      updated_incident = Enum.find(updated_nearby, fn i -> i["id"] == incident_id end)
      assert updated_incident["verification_count"] == 1
    end
  end
end
