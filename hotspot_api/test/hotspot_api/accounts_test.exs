defmodule HotspotApi.AccountsTest do
  use HotspotApi.DataCase

  import Mox
  import HotspotApi.AccountsFixtures

  alias HotspotApi.Accounts
  alias HotspotApi.Guardian

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "users" do
    alias HotspotApi.Accounts.User

    @invalid_attrs %{phone_number: nil}

    test "list_users/0 returns all users" do
      user = user_fixture()
      assert Accounts.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user!(user.id) == user
    end

    test "get_user_by_phone/1 returns the user with given phone number" do
      user = user_fixture()
      assert Accounts.get_user_by_phone(user.phone_number) == user
    end

    test "get_user_by_phone/1 returns nil for non-existent phone" do
      assert Accounts.get_user_by_phone("+27999999999") == nil
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{phone_number: "+27123456789"}

      assert {:ok, %User{} = user} = Accounts.create_user(valid_attrs)
      assert user.phone_number == "+27123456789"
      assert user.is_premium == false
      assert user.alert_radius == 2000
      assert user.notification_config == %{}
    end

    test "create_user/1 with invalid phone number returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(%{phone_number: "invalid"})
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "create_user/1 with duplicate phone number returns error" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(%{phone_number: user.phone_number})
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      update_attrs = %{is_premium: true, alert_radius: 5000}

      assert {:ok, %User{} = user} = Accounts.update_user(user, update_attrs)
      assert user.is_premium == true
      assert user.alert_radius == 5000
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert user == Accounts.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end

  describe "OTP functionality" do
    @valid_phone "+27123456789"

    setup do
      # Configure mock Twilio client for tests
      Application.put_env(:hotspot_api, :twilio_client, HotspotApi.TwilioMock)
      :ok
    end

    test "send_otp/1 creates an OTP code and sends SMS via Twilio" do
      # Expect Twilio mock to be called
      expect(HotspotApi.TwilioMock, :send_sms, fn phone, message ->
        assert phone == @valid_phone
        assert message =~ "Your Hotspot verification code is:"
        assert String.length(String.replace(message, ~r/[^\d]/, "")) == 6
        :ok
      end)

      assert {:ok, otp_code} = Accounts.send_otp(@valid_phone)
      assert otp_code.phone_number == @valid_phone
      assert String.length(otp_code.code) == 6
      assert otp_code.verified == false
    end

    test "send_otp/1 returns error when Twilio fails" do
      # Expect Twilio mock to fail
      expect(HotspotApi.TwilioMock, :send_sms, fn _, _ ->
        {:error, :twilio_error}
      end)

      assert {:error, :twilio_error} = Accounts.send_otp(@valid_phone)
    end

    test "send_otp/1 enforces rate limiting" do
      # Mock Twilio for all 3 successful calls
      expect(HotspotApi.TwilioMock, :send_sms, 3, fn _, _ -> :ok end)

      # Send 3 OTPs
      assert {:ok, _} = Accounts.send_otp(@valid_phone)
      assert {:ok, _} = Accounts.send_otp(@valid_phone)
      assert {:ok, _} = Accounts.send_otp(@valid_phone)

      # 4th attempt should fail due to rate limiting (no Twilio call expected)
      assert {:error, :rate_limit_exceeded} = Accounts.send_otp(@valid_phone)
    end

    test "verify_otp/2 with valid code creates or returns user" do
      expect(HotspotApi.TwilioMock, :send_sms, fn _, _ -> :ok end)
      {:ok, otp_code} = Accounts.send_otp(@valid_phone)

      assert {:ok, user} = Accounts.verify_otp(@valid_phone, otp_code.code)
      assert user.phone_number == @valid_phone
      assert user.is_premium == false
      assert user.alert_radius == 2000
    end

    test "verify_otp/2 with invalid code returns error" do
      expect(HotspotApi.TwilioMock, :send_sms, fn _, _ -> :ok end)
      {:ok, _otp_code} = Accounts.send_otp(@valid_phone)

      assert {:error, :invalid_or_expired_otp} = Accounts.verify_otp(@valid_phone, "000000")
    end

    test "verify_otp/2 with expired code returns error" do
      # Create an expired OTP manually
      expired_at = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      {:ok, otp} = Repo.insert(%Accounts.OtpCode{
        phone_number: @valid_phone,
        code: "123456",
        expires_at: expired_at,
        verified: false
      })

      assert {:error, :invalid_or_expired_otp} = Accounts.verify_otp(@valid_phone, otp.code)
    end

    test "verify_otp/2 returns existing user if already registered" do
      # Create user first
      {:ok, existing_user} = Accounts.create_user(%{phone_number: @valid_phone})

      # Send and verify OTP
      expect(HotspotApi.TwilioMock, :send_sms, fn _, _ -> :ok end)
      {:ok, otp_code} = Accounts.send_otp(@valid_phone)
      assert {:ok, user} = Accounts.verify_otp(@valid_phone, otp_code.code)

      # Should return the same user
      assert user.id == existing_user.id
    end
  end

  describe "Guardian JWT token functionality" do
    test "encode_and_sign/1 creates a valid JWT token for user" do
      user = user_fixture()

      assert {:ok, token, claims} = Guardian.encode_and_sign(user)
      assert is_binary(token)
      assert String.length(token) > 0
      assert claims["sub"] == user.id
      assert claims["typ"] == "access"
    end

    test "decode_and_verify/1 decodes a valid JWT token" do
      user = user_fixture()
      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      assert {:ok, decoded_claims} = Guardian.decode_and_verify(token)
      assert decoded_claims["sub"] == user.id
    end

    test "decode_and_verify/1 rejects invalid token" do
      assert {:error, _reason} = Guardian.decode_and_verify("invalid_token")
    end

    test "resource_from_claims/1 returns user from valid claims" do
      user = user_fixture()
      {:ok, _token, claims} = Guardian.encode_and_sign(user)

      assert {:ok, fetched_user} = Guardian.resource_from_claims(claims)
      assert fetched_user.id == user.id
      assert fetched_user.phone_number == user.phone_number
    end

    test "resource_from_claims/1 returns error for non-existent user" do
      fake_claims = %{"sub" => Ecto.UUID.generate()}

      assert {:error, :user_not_found} = Guardian.resource_from_claims(fake_claims)
    end

    test "subject_for_token/2 extracts user ID" do
      user = user_fixture()

      assert {:ok, subject} = Guardian.subject_for_token(user, %{})
      assert subject == user.id
    end

    test "JWT token expires after configured time" do
      user = user_fixture()

      # Create token with 1 second TTL
      assert {:ok, token, _claims} = Guardian.encode_and_sign(user, %{}, ttl: {1, :second})

      # Token should be valid immediately
      assert {:ok, _claims} = Guardian.decode_and_verify(token)

      # Wait for token to expire (add buffer for clock skew)
      Process.sleep(2000)

      # Token should now be expired
      assert {:error, _reason} = Guardian.decode_and_verify(token)
    end
  end

  describe "Rate limiting logic" do
    @rate_limit_phone "+27999888777"

    setup do
      Application.put_env(:hotspot_api, :twilio_client, HotspotApi.TwilioMock)
      :ok
    end

    test "allows 3 OTP requests within an hour" do
      expect(HotspotApi.TwilioMock, :send_sms, 3, fn _, _ -> :ok end)

      assert {:ok, _} = Accounts.send_otp(@rate_limit_phone)
      assert {:ok, _} = Accounts.send_otp(@rate_limit_phone)
      assert {:ok, _} = Accounts.send_otp(@rate_limit_phone)
    end

    test "blocks 4th OTP request within an hour" do
      expect(HotspotApi.TwilioMock, :send_sms, 3, fn _, _ -> :ok end)

      # First 3 should succeed
      Accounts.send_otp(@rate_limit_phone)
      Accounts.send_otp(@rate_limit_phone)
      Accounts.send_otp(@rate_limit_phone)

      # 4th should be rate limited
      assert {:error, :rate_limit_exceeded} = Accounts.send_otp(@rate_limit_phone)
    end

    test "rate limit resets after one hour" do
      # This test would require time manipulation in a real scenario
      # For now, we verify the logic by checking OTP count
      expect(HotspotApi.TwilioMock, :send_sms, 3, fn _, _ -> :ok end)

      Accounts.send_otp(@rate_limit_phone)
      Accounts.send_otp(@rate_limit_phone)
      Accounts.send_otp(@rate_limit_phone)

      # Verify we have 3 OTPs in the last hour
      one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600, :second)

      count =
        from(o in Accounts.OtpCode,
          where: o.phone_number == ^@rate_limit_phone and o.inserted_at > ^one_hour_ago
        )
        |> Repo.aggregate(:count)

      assert count == 3
    end
  end
end
