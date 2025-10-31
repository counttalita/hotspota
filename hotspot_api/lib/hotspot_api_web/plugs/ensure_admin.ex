defmodule HotspotApiWeb.Plugs.EnsureAdmin do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    resource = Guardian.Plug.current_resource(conn)
    claims = Guardian.Plug.current_claims(conn)

    cond do
      # Check if the resource is an admin user
      is_admin_user?(resource) && claims["type"] == "admin" ->
        conn

      true ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Admin access required"})
        |> halt()
    end
  end

  defp is_admin_user?(%HotspotApi.Admin.AdminUser{}), do: true
  defp is_admin_user?(_), do: false
end
