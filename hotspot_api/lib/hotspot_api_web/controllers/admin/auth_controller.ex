defmodule HotspotApiWeb.Admin.AuthController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Admin
  alias HotspotApi.Guardian

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  Admin login endpoint
  POST /api/admin/auth/login
  """
  def login(conn, %{"email" => email, "password" => password}) do
    case Admin.authenticate_admin(email, password) do
      {:ok, admin} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(admin, %{type: "admin"})

        conn
        |> put_status(:ok)
        |> json(%{
          user: %{
            id: admin.id,
            email: admin.email,
            name: admin.name,
            role: admin.role
          },
          token: token
        })

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
    end
  end

  @doc """
  Get current admin user
  GET /api/admin/auth/me
  """
  def me(conn, _params) do
    admin = Guardian.Plug.current_resource(conn)

    conn
    |> put_status(:ok)
    |> json(%{
      user: %{
        id: admin.id,
        email: admin.email,
        name: admin.name,
        role: admin.role,
        last_login_at: admin.last_login_at
      }
    })
  end

  @doc """
  Admin logout endpoint
  POST /api/admin/auth/logout
  """
  def logout(conn, _params) do
    conn
    |> Guardian.Plug.sign_out()
    |> put_status(:ok)
    |> json(%{message: "Logged out successfully"})
  end
end
