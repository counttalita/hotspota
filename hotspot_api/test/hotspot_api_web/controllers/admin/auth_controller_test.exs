defmodule HotspotApiWeb.Admin.AuthControllerTest do
  use HotspotApiWeb.ConnCase

  import HotspotApi.AdminFixtures

  alias HotspotApi.Admin
  alias HotspotApi.Guardian

  describe "POST /api/admin/auth/login" do
    setup do
      admin = admin_user_fixture(%{
        email: "admin@test.com",
        password: "SecurePassword123!",
        is_active: true
      })

      %{admin: admin}
    end

    test "logs in admin with valid credentials", %{conn: conn, admin: admin} do
      conn = post(conn, ~p"/api/admin/auth/login", %{
        email: "admin@test.com",
        password: "SecurePassword123!"
      })

      assert %{"token" => token, "admin" => admin_data} = json_response(conn, 200)
      assert is_binary(token)
      assert admin_data["email"] == admin.email
      assert admin_data["name"] == admin.name
      assert admin_data["role"] == admin.role

      # Verify token is valid
      assert {:ok, claims} = Guardian.decode_and_verify(token)
      assert claims["sub"] == admin.id
    end

    test "returns error with invalid password", %{conn: conn} do
      conn = post(conn, ~p"/api/admin/auth/login", %{
        email: "admin@test.com",
        password: "WrongPassword"
      })

      assert %{"error" => _message} = json_response(conn, 401)
    end

    test "returns error with non-existent email", %{conn: conn} do
      conn = post(conn, ~p"/api/admin/auth/login", %{
        email: "nonexistent@test.com",
        password: "SecurePassword123!"
      })

      assert %{"error" => _message} = json_response(conn, 401)
    end

    test "returns error with inactive admin account", %{conn: conn} do
      _inactive_admin = admin_user_fixture(%{
        email: "inactive@test.com",
        password: "SecurePassword123!",
        is_active: false
      })

      conn = post(conn, ~p"/api/admin/auth/login", %{
        email: "inactive@test.com",
        password: "SecurePassword123!"
      })

      assert %{"error" => _message} = json_response(conn, 401)
    end

    test "returns error with missing credentials", %{conn: conn} do
      conn = post(conn, ~p"/api/admin/auth/login", %{})

      assert %{"error" => _message} = json_response(conn, 400)
    end

    test "updates last_login_at timestamp on successful login", %{conn: conn, admin: admin} do
      assert admin.last_login_at == nil

      post(conn, ~p"/api/admin/auth/login", %{
        email: "admin@test.com",
        password: "SecurePassword123!"
      })

      updated_admin = Admin.get_admin!(admin.id)
      assert updated_admin.last_login_at != nil
    end
  end

  describe "GET /api/admin/auth/me" do
    setup do
      admin = admin_user_fixture()
      {:ok, token, _claims} = Guardian.encode_and_sign(admin, %{}, token_type: "access")

      %{admin: admin, token: token}
    end

    test "returns current admin with valid token", %{conn: conn, admin: admin, token: token} do
      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/admin/auth/me")

      assert %{"admin" => admin_data} = json_response(conn, 200)
      assert admin_data["id"] == admin.id
      assert admin_data["email"] == admin.email
      assert admin_data["name"] == admin.name
      assert admin_data["role"] == admin.role
    end

    test "returns error without token", %{conn: conn} do
      conn = get(conn, ~p"/api/admin/auth/me")

      assert json_response(conn, 401)
    end

    test "returns error with invalid token", %{conn: conn} do
      conn = conn
      |> put_req_header("authorization", "Bearer invalid_token")
      |> get(~p"/api/admin/auth/me")

      assert json_response(conn, 401)
    end
  end
end
