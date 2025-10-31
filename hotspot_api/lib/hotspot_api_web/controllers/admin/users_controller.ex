defmodule HotspotApiWeb.Admin.UsersController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Admin
  alias HotspotApi.Guardian

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  List users with pagination, search, and filters
  GET /api/admin/users
  """
  def index(conn, params) do
    admin = Guardian.Plug.current_resource(conn)

    # Extract pagination params
    page = Map.get(params, "page", "1") |> String.to_integer()
    page_size = Map.get(params, "page_size", "20") |> String.to_integer()

    # Extract filter params
    filters = %{
      is_premium: Map.get(params, "is_premium"),
      search: Map.get(params, "search"),
      start_date: Map.get(params, "start_date"),
      end_date: Map.get(params, "end_date")
    }

    # Extract sort params
    sort_by = Map.get(params, "sort_by", "inserted_at")
    sort_order = Map.get(params, "sort_order", "desc")

    result = Admin.list_users_paginated(page, page_size, filters, sort_by, sort_order)

    # Log admin action
    Admin.log_audit(admin.id, "list_users", "user", nil, %{filters: filters, page: page}, get_ip_address(conn))

    conn
    |> put_status(:ok)
    |> json(%{
      data: Enum.map(result.users, &serialize_user/1),
      pagination: %{
        page: result.page,
        page_size: result.page_size,
        total_count: result.total_count,
        total_pages: result.total_pages
      }
    })
  end

  @doc """
  Get single user details with incident history
  GET /api/admin/users/:id
  """
  def show(conn, %{"id" => id}) do
    admin = Guardian.Plug.current_resource(conn)

    user = Admin.get_user_with_details!(id)

    # Log admin action
    Admin.log_audit(admin.id, "view_user", "user", id, %{}, get_ip_address(conn))

    conn
    |> put_status(:ok)
    |> json(%{data: serialize_user_detail(user)})
  end

  @doc """
  Suspend user account
  PUT /api/admin/users/:id/suspend
  """
  def suspend(conn, %{"id" => id} = params) do
    admin = Guardian.Plug.current_resource(conn)
    reason = Map.get(params, "reason")

    case Admin.suspend_user(id, admin.id, reason) do
      {:ok, user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          data: serialize_user(user),
          message: "User suspended successfully"
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  @doc """
  Ban user account permanently
  PUT /api/admin/users/:id/ban
  """
  def ban(conn, %{"id" => id} = params) do
    admin = Guardian.Plug.current_resource(conn)
    reason = Map.get(params, "reason")

    case Admin.ban_user(id, admin.id, reason) do
      {:ok, user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          data: serialize_user(user),
          message: "User banned successfully"
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  @doc """
  Grant or revoke premium status
  PUT /api/admin/users/:id/premium
  """
  def update_premium(conn, %{"id" => id, "is_premium" => is_premium} = params) do
    admin = Guardian.Plug.current_resource(conn)
    expires_at = Map.get(params, "expires_at")

    # Parse expires_at if provided
    parsed_expires_at = if expires_at do
      case DateTime.from_iso8601(expires_at) do
        {:ok, datetime, _} -> datetime
        _ -> nil
      end
    else
      nil
    end

    case Admin.update_user_premium(id, is_premium, admin.id, parsed_expires_at) do
      {:ok, user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          data: serialize_user(user),
          message: "User premium status updated successfully"
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  @doc """
  Send notification to user
  POST /api/admin/users/:id/notify
  """
  def notify(conn, %{"id" => id, "title" => title, "message" => message}) do
    admin = Guardian.Plug.current_resource(conn)

    case Admin.send_user_notification(id, admin.id, title, message) do
      {:ok, result} ->
        conn
        |> put_status(:ok)
        |> json(%{
          message: result.message
        })

      {:error, :no_tokens_found} ->
        conn
        |> put_status(:ok)
        |> json(%{
          message: "User has no registered devices for notifications"
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  @doc """
  Get user activity log
  GET /api/admin/users/:id/activity
  """
  def activity(conn, %{"id" => id} = params) do
    admin = Guardian.Plug.current_resource(conn)
    limit = Map.get(params, "limit", "50") |> String.to_integer()

    activities = Admin.get_user_activity(id, limit)

    # Log admin action
    Admin.log_audit(admin.id, "view_user_activity", "user", id, %{limit: limit}, get_ip_address(conn))

    conn
    |> put_status(:ok)
    |> json(%{data: activities})
  end

  # Private helpers

  defp serialize_user(user) do
    %{
      id: user.id,
      phone_number: user.phone_number,
      is_premium: user.is_premium,
      premium_expires_at: user.premium_expires_at,
      alert_radius: user.alert_radius,
      notification_config: user.notification_config,
      created_at: user.inserted_at,
      updated_at: user.updated_at,
      is_suspended: get_in(user.notification_config, ["suspended"]) || false,
      is_banned: get_in(user.notification_config, ["banned"]) || false
    }
  end

  defp serialize_user_detail(user) do
    user
    |> serialize_user()
    |> Map.merge(%{
      incidents: Enum.map(user.incidents || [], &serialize_incident/1),
      verifications: Enum.map(user.verifications || [], &serialize_verification/1),
      incident_count: length(user.incidents || []),
      verification_count: length(user.verifications || [])
    })
  end

  defp serialize_incident(incident) do
    %{
      id: incident.id,
      type: incident.type,
      description: incident.description,
      location: serialize_location(incident.location),
      verification_count: incident.verification_count,
      is_verified: incident.is_verified,
      created_at: incident.inserted_at
    }
  end

  defp serialize_verification(verification) do
    %{
      id: verification.id,
      incident_id: verification.incident_id,
      created_at: verification.inserted_at
    }
  end

  defp serialize_location(%Geo.Point{coordinates: {lng, lat}}) do
    %{
      latitude: lat,
      longitude: lng
    }
  end

  defp serialize_location(_), do: nil

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp get_ip_address(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> to_string(:inet.ntoa(conn.remote_ip))
    end
  end
end
