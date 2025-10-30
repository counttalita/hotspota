defmodule HotspotApi.AccountsTest do
  use HotspotApi.DataCase

  alias HotspotApi.Accounts

  describe "users" do
    alias HotspotApi.Accounts.User

    import HotspotApi.AccountsFixtures

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

    test "send_otp/1 creates an OTP code" do
      assert {:ok, otp_code} = Accounts.send_otp(@valid_phone)
      assert otp_code.phone_number == @valid_phone
      assert String.length(otp_code.code) == 6
      assert otp_code.verified == false
    end

    test "send_otp/1 enforces rate limiting" do
      # Send 3 OTPs
      assert {:ok, _} = Accounts.send_otp(@valid_phone)
      assert {:ok, _} = Accounts.send_otp(@valid_phone)
      assert {:ok, _} = Accounts.send_otp(@valid_phone)

      # 4th attempt should fail
      assert {:error, :rate_limit_exceeded} = Accounts.send_otp(@valid_phone)
    end

    test "verify_otp/2 with valid code creates or returns user" do
      {:ok, otp_code} = Accounts.send_otp(@valid_phone)

      assert {:ok, user} = Accounts.verify_otp(@valid_phone, otp_code.code)
      assert user.phone_number == @valid_phone
      assert user.is_premium == false
      assert user.alert_radius == 2000
    end

    test "verify_otp/2 with invalid code returns error" do
      {:ok, _otp_code} = Accounts.send_otp(@valid_phone)

      assert {:error, :invalid_or_expired_otp} = Accounts.verify_otp(@valid_phone, "000000")
    end

    test "verify_otp/2 with expired code returns error" do
      # Create an expired OTP manually
      expired_at = DateTime.utc_now() |> DateTime.add(-3600, :second)

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
      {:ok, otp_code} = Accounts.send_otp(@valid_phone)
      assert {:ok, user} = Accounts.verify_otp(@valid_phone, otp_code.code)

      # Should return the same user
      assert user.id == existing_user.id
    end
  end
end
