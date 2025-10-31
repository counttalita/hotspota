defmodule HotspotApiWeb.Admin.IncidentsController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Admin
  alias HotspotApi.Incidents
  alias HotspotApi.Guardian

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  List incidents with pagination, search, and filters
  GET /api/admin/incidents
  """
  def index(conn, params) do
    admin = Guardian.Plug.current_resource(conn)

    # Extract pagination params
    page = Map.get(params, "page", "1") |> String.to_integer()
    page_size = Map.get(params, "page_size", "20") |> String.to_integer()

    # Extract filter params
    filters = %{
      type: Map.get(params, "type"),
      status: Map.get(params, "status"),
      search: Map.get(params, "search"),
      start_date: Map.get(params, "start_date"),
      end_date: Map.get(params, "end_date"),
      is_verified: Map.get(params, "is_verified")
    }

    # Extract sort params
    sort_by = Map.get(params, "sort_by", "inserted_at")
    sort_order = Map.get(params, "sort_order", "desc")

    result = Admin.list_incidents_paginated(page, page_size, filters, sort_by, sort_order)

    # Log admin action
    Admin.log_audit(admin.id, "list_incidents", "incident", nil, %{filters: filters, page: page}, get_ip_address(conn))

    conn
    |> put_status(:ok)
    |> json(%{
      data: Enum.map(result.incidents, &serialize_incident/1),
      pagination: %{
        page: result.page,
        page_size: result.page_size,
        total_count: result.total_count,
        total_pages: result.total_pages
      }
    })
  end

  @doc """
  Get single incident details
  GET /api/admin/incidents/:id
  """
  def show(conn, %{"id" => id}) do
    admin = Guardian.Plug.current_resource(conn)

    incident = Admin.get_incident_with_details!(id)

    # Log admin action
    Admin.log_audit(admin.id, "view_incident", "incident", id, %{}, get_ip_address(conn))

    conn
    |> put_status(:ok)
    |> json(%{data: serialize_incident_detail(incident)})
  end

  @doc """
  Moderate incident (approve, flag, delete)
  PUT /api/admin/incidents/:id/moderate
  """
  def moderate(conn, %{"id" => id, "action" => action} = params) do
    admin = Guardian.Plug.current_resource(conn)

    case Admin.moderate_incident(id, action, admin.id, Map.get(params, "reason")) do
      {:ok, incident} ->
        # Log admin action
        Admin.log_audit(admin.id, "moderate_incident", "incident", id, %{action: action, reason: Map.get(params, "reason")}, get_ip_address(conn))

        conn
        |> put_status(:ok)
        |> json(%{
          data: serialize_incident(incident),
          message: "Incident #{action} successfully"
        })

      {:error, :invalid_action} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid action. Must be one of: approve, flag, delete"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  @doc """
  Bulk action on multiple incidents
  POST /api/admin/incidents/bulk-action
  """
  def bulk_action(conn, %{"incident_ids" => incident_ids, "action" => action} = params) do
    admin = Guardian.Plug.current_resource(conn)

    case Admin.bulk_moderate_incidents(incident_ids, action, admin.id, Map.get(params, "reason")) do
      {:ok, count} ->
        # Log admin action
        Admin.log_audit(admin.id, "bulk_moderate_incidents", "incident", nil, %{action: action, count: count, incident_ids: incident_ids}, get_ip_address(conn))

        conn
        |> put_status(:ok)
        |> json(%{
          message: "#{count} incidents #{action} successfully",
          count: count
        })

      {:error, :invalid_action} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid action. Must be one of: approve, flag, delete"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  @doc """
  Delete incident
  DELETE /api/admin/incidents/:id
  """
  def delete(conn, %{"id" => id}) do
    admin = Guardian.Plug.current_resource(conn)

    incident = Incidents.get_incident!(id)

    case Incidents.delete_incident(incident) do
      {:ok, _incident} ->
        # Log admin action
        Admin.log_audit(admin.id, "delete_incident", "incident", id, %{}, get_ip_address(conn))

        conn
        |> put_status(:ok)
        |> json(%{message: "Incident deleted successfully"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  # Private helpers

  defp serialize_incident(incident) do
    %{
      id: incident.id,
      type: incident.type,
      description: incident.description,
      photo_url: incident.photo_url,
      location: serialize_location(incident.location),
      verification_count: incident.verification_count,
      is_verified: incident.is_verified,
      status: Map.get(incident, :status, "active"),
      created_at: incident.inserted_at,
      expires_at: incident.expires_at,
      user: serialize_user(incident.user)
    }
  end

  defp serialize_incident_detail(incident) do
    incident
    |> serialize_incident()
    |> Map.merge(%{
      verifications: Enum.map(incident.verifications || [], &serialize_verification/1),
      flagged_content: Enum.map(incident.flagged_content || [], &serialize_flagged_content/1)
    })
  end

  defp serialize_location(%Geo.Point{coordinates: {lng, lat}}) do
    %{
      latitude: lat,
      longitude: lng
    }
  end

  defp serialize_location(_), do: nil

  defp serialize_user(nil), do: nil
  defp serialize_user(user) do
    %{
      id: user.id,
      phone_number: user.phone_number,
      is_premium: user.is_premium
    }
  end

  defp serialize_verification(verification) do
    %{
      id: verification.id,
      user_id: verification.user_id,
      created_at: verification.inserted_at
    }
  end

  defp serialize_flagged_content(flagged) do
    %{
      id: flagged.id,
      content_type: flagged.content_type,
      flag_reason: flagged.flag_reason,
      status: flagged.status,
      created_at: flagged.inserted_at
    }
  end

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
