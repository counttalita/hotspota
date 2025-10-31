defmodule HotspotApiWeb.Admin.ZonesController do
  use HotspotApiWeb, :controller

  import Ecto.Query, warn: false

  alias HotspotApi.Geofencing
  alias HotspotApi.Incidents
  alias HotspotApi.Admin
  alias HotspotApi.Guardian

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  List all hotspot zones with optional filtering
  GET /api/admin/zones
  """
  def index(conn, params) do
    admin = Guardian.Plug.current_resource(conn)

    # Parse query parameters
    page = Map.get(params, "page", "1") |> String.to_integer()
    page_size = Map.get(params, "page_size", "20") |> String.to_integer()
    is_active = Map.get(params, "is_active")
    zone_type = Map.get(params, "zone_type")
    risk_level = Map.get(params, "risk_level")

    # Build filters
    filters = %{
      is_active: is_active,
      zone_type: zone_type,
      risk_level: risk_level
    }

    # Get paginated zones
    result = list_zones_paginated(page, page_size, filters)

    # Log admin action
    Admin.log_audit(admin.id, "list_zones", "hotspot_zone", nil, filters, get_ip_address(conn))

    conn
    |> put_status(:ok)
    |> json(%{
      data: Enum.map(result.zones, &serialize_zone/1),
      pagination: %{
        page: result.page,
        page_size: result.page_size,
        total_count: result.total_count,
        total_pages: result.total_pages
      }
    })
  end

  @doc """
  Get a single hotspot zone with details
  GET /api/admin/zones/:id
  """
  def show(conn, %{"id" => id}) do
    admin = Guardian.Plug.current_resource(conn)

    zone = Geofencing.get_zone!(id)

    # Log admin action
    Admin.log_audit(admin.id, "view_zone", "hotspot_zone", id, %{}, get_ip_address(conn))

    conn
    |> put_status(:ok)
    |> json(%{data: serialize_zone(zone)})
  end

  @doc """
  Create a new hotspot zone manually
  POST /api/admin/zones
  """
  def create(conn, params) do
    admin = Guardian.Plug.current_resource(conn)

    # Validate required parameters
    with {:ok, attrs} <- validate_zone_params(params),
         {:ok, _overlap_check} <- check_zone_overlap(attrs),
         {:ok, zone} <- Geofencing.create_zone(attrs) do

      # Log admin action
      Admin.log_audit(admin.id, "create_zone", "hotspot_zone", zone.id, attrs, get_ip_address(conn))

      conn
      |> put_status(:created)
      |> json(%{data: serialize_zone(zone)})
    else
      {:error, :overlap} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Zone overlaps significantly (>50%) with an existing zone"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Validation failed", details: translate_errors(changeset)})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  @doc """
  Update a hotspot zone
  PUT /api/admin/zones/:id
  """
  def update(conn, %{"id" => id} = params) do
    admin = Guardian.Plug.current_resource(conn)

    zone = Geofencing.get_zone!(id)

    # Extract update attributes
    attrs = extract_update_attrs(params)

    # Check for overlap if location or radius changed
    overlap_check = if Map.has_key?(attrs, :latitude) or Map.has_key?(attrs, :longitude) or Map.has_key?(attrs, :radius_meters) do
      check_zone_overlap(Map.merge(serialize_zone_to_attrs(zone), attrs), id)
    else
      {:ok, :no_overlap}
    end

    with {:ok, _} <- overlap_check,
         {:ok, updated_zone} <- Geofencing.update_zone(zone, attrs) do

      # Log admin action
      Admin.log_audit(admin.id, "update_zone", "hotspot_zone", id, attrs, get_ip_address(conn))

      conn
      |> put_status(:ok)
      |> json(%{data: serialize_zone(updated_zone)})
    else
      {:error, :overlap} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Zone overlaps significantly (>50%) with an existing zone"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Validation failed", details: translate_errors(changeset)})
    end
  end

  @doc """
  Delete/dissolve a hotspot zone
  DELETE /api/admin/zones/:id
  """
  def delete(conn, %{"id" => id}) do
    admin = Guardian.Plug.current_resource(conn)

    zone = Geofencing.get_zone!(id)

    with {:ok, _zone} <- Geofencing.delete_zone(zone) do
      # Log admin action
      Admin.log_audit(admin.id, "delete_zone", "hotspot_zone", id, %{}, get_ip_address(conn))

      conn
      |> put_status(:ok)
      |> json(%{message: "Zone deleted successfully"})
    end
  end

  @doc """
  Get incidents within a specific zone
  GET /api/admin/zones/:id/incidents
  """
  def incidents(conn, %{"id" => id} = params) do
    admin = Guardian.Plug.current_resource(conn)

    zone = Geofencing.get_zone!(id)

    # Parse pagination parameters
    page = Map.get(params, "page", "1") |> String.to_integer()
    page_size = Map.get(params, "page_size", "20") |> String.to_integer()

    # Get zone center coordinates
    %Geo.Point{coordinates: {lng, lat}} = zone.center_location

    # Get incidents near zone center within zone radius
    all_incidents = Incidents.list_nearby(lat, lng, zone.radius_meters)

    # Filter by zone type
    filtered_incidents = Enum.filter(all_incidents, fn incident ->
      incident.type == zone.zone_type
    end)

    # Apply pagination
    total_count = length(filtered_incidents)
    total_pages = ceil(total_count / page_size)

    paginated_incidents = filtered_incidents
      |> Enum.drop((page - 1) * page_size)
      |> Enum.take(page_size)

    # Log admin action
    Admin.log_audit(admin.id, "view_zone_incidents", "hotspot_zone", id, %{page: page}, get_ip_address(conn))

    conn
    |> put_status(:ok)
    |> json(%{
      data: Enum.map(paginated_incidents, &serialize_incident/1),
      pagination: %{
        page: page,
        page_size: page_size,
        total_count: total_count,
        total_pages: total_pages
      }
    })
  end

  @doc """
  Get zone entry/exit statistics
  GET /api/admin/zones/:id/stats
  """
  def stats(conn, %{"id" => id}) do
    admin = Guardian.Plug.current_resource(conn)

    zone = Geofencing.get_zone!(id)

    # Get zone statistics
    stats = get_zone_stats(zone)

    # Log admin action
    Admin.log_audit(admin.id, "view_zone_stats", "hotspot_zone", id, %{}, get_ip_address(conn))

    conn
    |> put_status(:ok)
    |> json(%{data: stats})
  end

  # Private helper functions

  defp list_zones_paginated(page, page_size, filters) do
    import Ecto.Query

    # Build base query
    query = from(z in HotspotApi.Geofencing.HotspotZone)

    # Apply filters
    query = apply_zone_filters(query, filters)

    # Get total count
    total_count = HotspotApi.Repo.aggregate(query, :count, :id)

    # Apply sorting (by incident count descending)
    query = order_by(query, [z], desc: z.incident_count, desc: z.inserted_at)

    # Apply pagination
    zones = query
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> HotspotApi.Repo.all()

    total_pages = ceil(total_count / page_size)

    %{
      zones: zones,
      total_count: total_count,
      page: page,
      page_size: page_size,
      total_pages: total_pages
    }
  end

  defp apply_zone_filters(query, filters) do
    import Ecto.Query

    query
    |> filter_by_active_status(filters.is_active)
    |> filter_by_zone_type(filters.zone_type)
    |> filter_by_risk_level(filters.risk_level)
  end

  defp filter_by_active_status(query, nil), do: query
  defp filter_by_active_status(query, ""), do: query
  defp filter_by_active_status(query, "true"), do: where(query, [z], z.is_active == true)
  defp filter_by_active_status(query, "false"), do: where(query, [z], z.is_active == false)
  defp filter_by_active_status(query, _), do: query

  defp filter_by_zone_type(query, nil), do: query
  defp filter_by_zone_type(query, ""), do: query
  defp filter_by_zone_type(query, type), do: where(query, [z], z.zone_type == ^type)

  defp filter_by_risk_level(query, nil), do: query
  defp filter_by_risk_level(query, ""), do: query
  defp filter_by_risk_level(query, level), do: where(query, [z], z.risk_level == ^level)

  defp validate_zone_params(params) do
    required_fields = ["zone_type", "latitude", "longitude", "radius_meters"]

    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(params, field) or is_nil(params[field])
    end)

    if Enum.empty?(missing_fields) do
      attrs = %{
        zone_type: params["zone_type"],
        latitude: parse_float(params["latitude"]),
        longitude: parse_float(params["longitude"]),
        radius_meters: parse_integer(params["radius_meters"]),
        incident_count: parse_integer(params["incident_count"]) || 0,
        risk_level: params["risk_level"] || "low",
        is_active: parse_boolean(params["is_active"]) || true
      }

      {:ok, attrs}
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp extract_update_attrs(params) do
    attrs = %{}

    attrs = if Map.has_key?(params, "latitude"), do: Map.put(attrs, :latitude, parse_float(params["latitude"])), else: attrs
    attrs = if Map.has_key?(params, "longitude"), do: Map.put(attrs, :longitude, parse_float(params["longitude"])), else: attrs
    attrs = if Map.has_key?(params, "radius_meters"), do: Map.put(attrs, :radius_meters, parse_integer(params["radius_meters"])), else: attrs
    attrs = if Map.has_key?(params, "risk_level"), do: Map.put(attrs, :risk_level, params["risk_level"]), else: attrs
    attrs = if Map.has_key?(params, "is_active"), do: Map.put(attrs, :is_active, parse_boolean(params["is_active"])), else: attrs
    attrs = if Map.has_key?(params, "incident_count"), do: Map.put(attrs, :incident_count, parse_integer(params["incident_count"])), else: attrs

    attrs
  end

  defp check_zone_overlap(attrs, exclude_zone_id \\ nil) do
    import Ecto.Query
    import Geo.PostGIS

    latitude = attrs[:latitude] || attrs["latitude"]
    longitude = attrs[:longitude] || attrs["longitude"]
    radius = attrs[:radius_meters] || attrs["radius_meters"]
    zone_type = attrs[:zone_type] || attrs["zone_type"]

    point = %Geo.Point{coordinates: {longitude, latitude}, srid: 4326}

    # Find nearby zones of the same type
    query = from(z in HotspotApi.Geofencing.HotspotZone,
      where: z.zone_type == ^zone_type,
      where: z.is_active == true,
      where: st_dwithin_in_meters(z.center_location, ^point, ^(radius + 1000))
    )

    # Exclude current zone if updating
    query = if exclude_zone_id do
      where(query, [z], z.id != ^exclude_zone_id)
    else
      query
    end

    nearby_zones = HotspotApi.Repo.all(query)

    # Check for significant overlap (>50%)
    overlapping = Enum.any?(nearby_zones, fn zone ->
      %Geo.Point{coordinates: {z_lng, z_lat}} = zone.center_location
      distance = calculate_distance(latitude, longitude, z_lat, z_lng)

      # Calculate overlap percentage
      # If distance < sum of radii, there's overlap
      if distance < (radius + zone.radius_meters) do
        # Calculate overlap area (simplified)
        overlap_distance = (radius + zone.radius_meters) - distance
        overlap_percentage = (overlap_distance / min(radius, zone.radius_meters)) * 100

        overlap_percentage > 50
      else
        false
      end
    end)

    if overlapping do
      {:error, :overlap}
    else
      {:ok, :no_overlap}
    end
  end

  defp get_zone_stats(zone) do
    import Ecto.Query

    # Get entry/exit statistics
    tracking_query = from(t in HotspotApi.Geofencing.UserZoneTracking,
      where: t.zone_id == ^zone.id
    )

    total_entries = HotspotApi.Repo.aggregate(tracking_query, :count, :id)

    # Count users currently in zone (no exit time)
    current_users = tracking_query
      |> where([t], is_nil(t.exited_at))
      |> HotspotApi.Repo.aggregate(:count, :id)

    # Count completed visits (with exit time)
    completed_visits = tracking_query
      |> where([t], not is_nil(t.exited_at))
      |> HotspotApi.Repo.aggregate(:count, :id)

    # Calculate average visit duration
    avg_duration_query = from(t in HotspotApi.Geofencing.UserZoneTracking,
      where: t.zone_id == ^zone.id and not is_nil(t.exited_at),
      select: fragment("AVG(EXTRACT(EPOCH FROM (? - ?)))", t.exited_at, t.entered_at)
    )

    avg_duration_seconds = HotspotApi.Repo.one(avg_duration_query) || 0

    # Get recent entries (last 24 hours)
    twenty_four_hours_ago = DateTime.add(DateTime.utc_now(), -24, :hour)
    recent_entries = tracking_query
      |> where([t], t.entered_at >= ^twenty_four_hours_ago)
      |> HotspotApi.Repo.aggregate(:count, :id)

    %{
      total_entries: total_entries,
      current_users: current_users,
      completed_visits: completed_visits,
      avg_duration_minutes: round(avg_duration_seconds / 60),
      recent_entries_24h: recent_entries,
      zone_age_days: DateTime.diff(DateTime.utc_now(), zone.inserted_at, :day)
    }
  end

  defp serialize_zone(zone) do
    %Geo.Point{coordinates: {lng, lat}} = zone.center_location

    %{
      id: zone.id,
      zone_type: zone.zone_type,
      center_location: %{
        latitude: lat,
        longitude: lng
      },
      radius_meters: zone.radius_meters,
      incident_count: zone.incident_count,
      risk_level: zone.risk_level,
      is_active: zone.is_active,
      last_incident_at: zone.last_incident_at,
      created_at: zone.inserted_at,
      updated_at: zone.updated_at
    }
  end

  defp serialize_zone_to_attrs(zone) do
    %Geo.Point{coordinates: {lng, lat}} = zone.center_location

    %{
      zone_type: zone.zone_type,
      latitude: lat,
      longitude: lng,
      radius_meters: zone.radius_meters
    }
  end

  defp serialize_incident(incident) do
    %Geo.Point{coordinates: {lng, lat}} = incident.location

    %{
      id: incident.id,
      type: incident.type,
      location: %{
        latitude: lat,
        longitude: lng
      },
      description: incident.description,
      photo_url: incident.photo_url,
      verification_count: incident.verification_count,
      is_verified: incident.is_verified,
      created_at: incident.inserted_at,
      expires_at: incident.expires_at
    }
  end

  defp calculate_distance(lat1, lng1, lat2, lng2) do
    r = 6371000 # Earth's radius in meters

    phi1 = lat1 * :math.pi() / 180
    phi2 = lat2 * :math.pi() / 180
    delta_phi = (lat2 - lat1) * :math.pi() / 180
    delta_lambda = (lng2 - lng1) * :math.pi() / 180

    a = :math.sin(delta_phi / 2) * :math.sin(delta_phi / 2) +
        :math.cos(phi1) * :math.cos(phi2) *
        :math.sin(delta_lambda / 2) * :math.sin(delta_lambda / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))

    round(r * c)
  end

  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_binary(value), do: String.to_float(value)
  defp parse_float(value) when is_integer(value), do: value * 1.0
  defp parse_float(_), do: nil

  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(value) when is_binary(value), do: String.to_integer(value)
  defp parse_integer(_), do: nil

  defp parse_boolean("true"), do: true
  defp parse_boolean("false"), do: false
  defp parse_boolean(true), do: true
  defp parse_boolean(false), do: false
  defp parse_boolean(_), do: nil

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
