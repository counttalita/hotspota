defmodule HotspotApiWeb.AuthControllerTest do
  use HotspotApiWeb.ConnCase

  alias HotspotApi.Accounts
  alias HotspotApi.Guardian
  alias HotspotApi.Repo

  @valid_phone "+27123456789"
  @invalid_phone "invalid"

  describe "POST /api/auth/send-otp" do
    test "sends OTP with valid phone number", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/send-otp", %{phone_number: @valid_phone})

      assert json_response(conn, 200)["message"] == "OTP sent successfully"
      assert json_response(conn, 200)["expires_in"] == 600
    end

    test "returns error with invalid phone number", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/send-otp", %{phone_number: @invalid_phone})

      assert json_response(conn, 400)["error"]["code"] == "validation_error"
    end

    test "returns error when phone_number is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/send-otp", %{})

      assert json_response(conn, 400)["error"]["code"] == "missing_parameter"
    end

    test "enforces rate limiting after 3 requests", %{conn: conn} do
      # Send 3 OTPs
      post(conn, ~p"/api/auth/send-otp", %{phone_number: @valid_phone})
      post(conn, ~p"/api/auth/send-otp", %{phone_number: @valid_phone})
      post(conn, ~p"/api/auth/send-otp", %{phone_number: @valid_phone})

      # 4th request should be rate limited
      conn = post(conn, ~p"/api/auth/send-otp", %{phone_number: @valid_phone})

      assert json_response(conn, 429)["error"]["code"] == "rate_limit_exceeded"
    end
  end

  describe "POST /api/auth/verify-otp" do
    setup do
      {:ok, otp_code} = Accounts.send_otp(@valid_phone)
      %{otp_code: otp_code}
    end

    test "verifies OTP and returns token with valid code", %{conn: conn, otp_code: otp_code} do
      conn = post(conn, ~p"/api/auth/verify-otp", %{
        phone_number: @valid_phone,
        code: otp_code.code
      })

      response = json_response(conn, 200)
      assert response["token"]
      assert response["user"]["phone_number"] == @valid_phone
      assert response["user"]["is_premium"] == false
      assert response["user"]["alert_radius"] == 2000
    end

    test "returns error with invalid OTP code", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/verify-otp", %{
        phone_number: @valid_phone,
        code: "000000"
      })

      assert json_response(conn, 401)["error"]["code"] == "invalid_otp"
    end

    test "returns error when parameters are missing", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/verify-otp", %{})

      assert json_response(conn, 400)["error"]["code"] == "missing_parameters"
    end

    test "creates new user on first verification", %{conn: conn, otp_code: otp_code} do
      conn = post(conn, ~p"/api/auth/verify-otp", %{
        phone_number: @valid_phone,
        code: otp_code.code
      })

      assert json_response(conn, 200)["user"]["id"]

      # Verify user was created in database
      user = Accounts.get_user_by_phone(@valid_phone)
      assert user != nil
    end

    test "returns existing user on subsequent verifications", %{conn: conn} do
      # First verification
      {:ok, otp1} = Accounts.send_otp(@valid_phone)
      conn1 = post(conn, ~p"/api/auth/verify-otp", %{
        phone_number: @valid_phone,
        code: otp1.code
      })
      user_id1 = json_response(conn1, 200)["user"]["id"]

      # Second verification
      {:ok, otp2} = Accounts.send_otp(@valid_phone)
      conn2 = post(conn, ~p"/api/auth/verify-otp", %{
        phone_number: @valid_phone,
        code: otp2.code
      })
      user_id2 = json_response(conn2, 200)["user"]["id"]

      # Should be the same user
      assert user_id1 == user_id2
    end

    test "returns error with expired OTP", %{conn: conn} do
      # Create expired OTP
      expired_at = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      {:ok, otp} = Repo.insert(%Accounts.OtpCode{
        phone_number: @valid_phone,
        code: "123456",
        expires_at: expired_at,
        verified: false
      })

      conn = post(conn, ~p"/api/auth/verify-otp", %{
        phone_number: @valid_phone,
        code: otp.code
      })

      assert json_response(conn, 401)["error"]["code"] == "invalid_otp"
    end
  end

  describe "GET /api/auth/me" do
    setup do
      {:ok, user} = Accounts.create_user(%{phone_number: @valid_phone})
      {:ok, token, _claims} = Guardian.encode_and_sign(user)
      %{user: user, token: token}
    end

    test "returns user info with valid token", %{conn: conn, token: token, user: user} do
      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/auth/me")

      response = json_response(conn, 200)
      assert response["user"]["id"] == user.id
      assert response["user"]["phone_number"] == @valid_phone
      assert response["user"]["is_premium"] == false
      assert response["user"]["alert_radius"] == 2000
    end

    test "returns error without token", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/me")

      assert json_response(conn, 401)["error"]["code"] == "unauthenticated"
    end

    test "returns error with invalid token", %{conn: conn} do
      conn = conn
        |> put_req_header("authorization", "Bearer invalid_token")
        |> get(~p"/api/auth/me")

      assert json_response(conn, 401)["error"]["code"] == "invalid_token"
    end
  end
end
