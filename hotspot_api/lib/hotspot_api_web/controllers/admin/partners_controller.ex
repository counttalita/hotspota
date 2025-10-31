defmodule HotspotApiWeb.Admin.PartnersController do
  use HotspotApiWeb, :controller

  alias HotspotApi.{Admin, Monetization}
  alias HotspotApi.Guardian

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  GET /api/admin/partners
  Lists all partners with optional filtering and pagination.
  Query params: page, page_size, is_active, partner_type, search
  """
  def index(conn, params) do
    admin = Guardian.Plug.current_resource(conn)

    page = String.to_integer(params["page"] || "1")
    page_size = String.to_integer(params["page_size"] || "20")

    filters = %{
      is_active: params["is_active"],
      partner_type: params["partner_type"],
      search: params["search"]
    }

    result = Monetization.list_partners_paginated(page, page_size, filters)

    # Log admin action
    Admin.log_audit(
      admin.id,
      "list_partners",
      "partner",
      nil,
      %{page: page, filters: filters},
      get_ip_address(conn)
    )

    conn
    |> put_status(:ok)
    |> json(%{
      data: result.partners,
      pagination: %{
        page: result.page,
        page_size: result.page_size,
        total_count: result.total_count,
        total_pages: result.total_pages
      }
    })
  end

  @doc """
  GET /api/admin/partners/:id
  Gets a single partner with details.
  """
  def show(conn, %{"id" => id}) do
    admin = Guardian.Plug.current_resource(conn)

    partner = Monetization.get_partner!(id)

    # Log admin action
    Admin.log_audit(
      admin.id,
      "view_partner",
      "partner",
      id,
      %{},
      get_ip_address(conn)
    )

    conn
    |> put_status(:ok)
    |> json(%{data: partner})
  end

  @doc """
  POST /api/admin/partners
  Creates a new partner.
  Body params: name, logo_url, partner_type, service_regions, monthly_fee, contract_start, contract_end, contact_email, contact_phone
  """
  def create(conn, params) do
    admin = Guardian.Plug.current_resource(conn)

    case Monetization.create_partner(params) do
      {:ok, partner} ->
        # Log admin action
        Admin.log_audit(
          admin.id,
          "create_partner",
          "partner",
          partner.id,
          %{name: partner.name, partner_type: partner.partner_type},
          get_ip_address(conn)
        )

        conn
        |> put_status(:created)
        |> json(%{data: partner})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  @doc """
  PUT /api/admin/partners/:id
  Updates an existing partner.
  Body params: name, logo_url, partner_type, service_regions, is_active, monthly_fee, contract_start, contract_end, contact_email, contact_phone
  """
  def update(conn, %{"id" => id} = params) do
    admin = Guardian.Plug.current_resource(conn)

    partner = Monetization.get_partner!(id)

    case Monetization.update_partner(partner, params) do
      {:ok, updated_partner} ->
        # Log admin action
        Admin.log_audit(
          admin.id,
          "update_partner",
          "partner",
          id,
          %{changes: params},
          get_ip_address(conn)
        )

        conn
        |> put_status(:ok)
        |> json(%{data: updated_partner})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  @doc """
  DELETE /api/admin/partners/:id
  Deletes a partner.
  """
  def delete(conn, %{"id" => id}) do
    admin = Guardian.Plug.current_resource(conn)

    partner = Monetization.get_partner!(id)

    case Monetization.delete_partner(partner) do
      {:ok, _partner} ->
        # Log admin action
        Admin.log_audit(
          admin.id,
          "delete_partner",
          "partner",
          id,
          %{name: partner.name},
          get_ip_address(conn)
        )

        conn
        |> put_status(:ok)
        |> json(%{message: "Partner deleted successfully"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  @doc """
  GET /api/admin/partners/:id/stats
  Gets partner statistics including impressions, clicks, and revenue.
  Query params: start_date, end_date (ISO8601 format)
  """
  def stats(conn, %{"id" => id} = params) do
    admin = Guardian.Plug.current_resource(conn)

    {start_date, end_date} = parse_date_range(params)

    stats = Monetization.get_partner_stats(id, start_date, end_date)

    # Log admin action
    Admin.log_audit(
      admin.id,
      "view_partner_stats",
      "partner",
      id,
      %{start_date: start_date, end_date: end_date},
      get_ip_address(conn)
    )

    conn
    |> put_status(:ok)
    |> json(%{data: stats})
  end

  # Private helper functions

  defp parse_date_range(params) do
    start_date_str = Map.get(params, "start_date")
    end_date_str = Map.get(params, "end_date")

    # Default to last 30 days if not provided
    default_end = DateTime.utc_now()
    default_start = DateTime.add(default_end, -30, :day)

    start_date = case start_date_str do
      nil -> default_start
      str ->
        case DateTime.from_iso8601(str) do
          {:ok, datetime, _} -> datetime
          _ ->
            # Try parsing as date only
            case Date.from_iso8601(str) do
              {:ok, date} -> DateTime.new!(date, ~T[00:00:00])
              _ -> default_start
            end
        end
    end

    end_date = case end_date_str do
      nil -> default_end
      str ->
        case DateTime.from_iso8601(str) do
          {:ok, datetime, _} -> datetime
          _ ->
            # Try parsing as date only
            case Date.from_iso8601(str) do
              {:ok, date} -> DateTime.new!(date, ~T[23:59:59])
              _ -> default_end
            end
        end
    end

    {start_date, end_date}
  end

  defp get_ip_address(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> to_string(:inet.ntoa(conn.remote_ip))
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
