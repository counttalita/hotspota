defmodule HotspotApi.Admin do
  @moduledoc """
  The Admin context for managing admin users and authentication.
  """

  import Ecto.Query, warn: false
  alias HotspotApi.Repo
  alias HotspotApi.Admin.AdminUser

  @doc """
  Gets a single admin user by email.
  """
  def get_admin_by_email(email) when is_binary(email) do
    Repo.get_by(AdminUser, email: email)
  end

  @doc """
  Gets a single admin user by id.
  """
  def get_admin!(id), do: Repo.get!(AdminUser, id)

  @doc """
  Authenticates an admin user with email and password.
  """
  def authenticate_admin(email, password) when is_binary(email) and is_binary(password) do
    admin = get_admin_by_email(email)

    cond do
      admin && admin.is_active && Argon2.verify_pass(password, admin.password_hash) ->
        update_last_login(admin)
        {:ok, admin}

      admin ->
        Argon2.no_user_verify()
        {:error, :invalid_credentials}

      true ->
        Argon2.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  @doc """
  Creates an admin user.
  """
  def create_admin(attrs \\ %{}) do
    %AdminUser{}
    |> AdminUser.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an admin user.
  """
  def update_admin(%AdminUser{} = admin, attrs) do
    admin
    |> AdminUser.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates the last login timestamp for an admin user.
  """
  def update_last_login(%AdminUser{} = admin) do
    admin
    |> Ecto.Changeset.change(last_login_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  @doc """
  Lists all admin users.
  """
  def list_admins do
    Repo.all(AdminUser)
  end

  @doc """
  Gets dashboard statistics including total incidents, active users, hotspot zones, and verification rate.
  """
  def get_dashboard_stats do
    now = DateTime.utc_now()
    thirty_days_ago = DateTime.add(now, -30, :day)

    # Total incidents (not expired)
    total_incidents = from(i in HotspotApi.Incidents.Incident,
      where: i.expires_at > ^now,
      select: count(i.id)
    ) |> Repo.one()

    # Active users (logged in within 30 days)
    active_users = from(u in HotspotApi.Accounts.User,
      where: u.updated_at > ^thirty_days_ago,
      select: count(u.id)
    ) |> Repo.one()

    # Active hotspot zones
    hotspot_zones = from(z in HotspotApi.Geofencing.HotspotZone,
      where: z.is_active == true,
      select: count(z.id)
    ) |> Repo.one()

    # Verification rate (percentage of verified incidents)
    verified_count = from(i in HotspotApi.Incidents.Incident,
      where: i.expires_at > ^now and i.is_verified == true,
      select: count(i.id)
    ) |> Repo.one()

    verification_rate = if total_incidents > 0 do
      Float.round(verified_count / total_incidents * 100, 1)
    else
      0.0
    end

    # Revenue this month (if subscriptions exist)
    start_of_month = DateTime.utc_now() |> DateTime.to_date() |> Date.beginning_of_month() |> DateTime.new!(~T[00:00:00])
    revenue_this_month = from(s in HotspotApi.Accounts.Subscription,
      where: s.inserted_at >= ^start_of_month and s.status == "active",
      select: sum(s.amount)
    ) |> Repo.one() || 0

    %{
      total_incidents: total_incidents,
      active_users: active_users,
      hotspot_zones: hotspot_zones,
      verification_rate: verification_rate,
      revenue_this_month: revenue_this_month
    }
  end

  @doc """
  Gets recent activity feed for the dashboard.
  Returns a list of recent incidents, verifications, and user registrations.
  """
  def get_recent_activity(limit \\ 20) do
    # Get recent incidents
    recent_incidents = from(i in HotspotApi.Incidents.Incident,
      order_by: [desc: i.inserted_at],
      limit: ^limit,
      preload: [:user]
    ) |> Repo.all()

    # Transform to activity format
    Enum.map(recent_incidents, fn incident ->
      %{
        id: incident.id,
        type: "incident_created",
        description: "New #{incident.type} reported",
        incident_type: incident.type,
        user_id: incident.user_id,
        user_phone: incident.user && incident.user.phone_number,
        created_at: incident.inserted_at,
        metadata: %{
          incident_id: incident.id,
          location: serialize_location(incident.location),
          is_verified: incident.is_verified
        }
      }
    end)
  end

  @doc """
  Lists incidents with pagination, filtering, and sorting for admin panel.
  """
  def list_incidents_paginated(page, page_size, filters, sort_by, sort_order) do
    now = DateTime.utc_now()

    # Build base query
    query = from(i in HotspotApi.Incidents.Incident,
      preload: [:user]
    )

    # Apply filters
    query = apply_incident_filters(query, filters, now)

    # Get total count
    total_count = Repo.aggregate(query, :count, :id)

    # Apply sorting
    query = apply_sorting(query, sort_by, sort_order)

    # Apply pagination
    incidents = query
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> Repo.all()

    total_pages = ceil(total_count / page_size)

    %{
      incidents: incidents,
      total_count: total_count,
      page: page,
      page_size: page_size,
      total_pages: total_pages
    }
  end

  defp apply_incident_filters(query, filters, now) do
    query
    |> filter_by_type(filters.type)
    |> filter_by_status(filters.status, now)
    |> filter_by_verified(filters.is_verified)
    |> filter_by_search(filters.search)
    |> filter_by_date_range(filters.start_date, filters.end_date)
  end

  defp filter_by_type(query, nil), do: query
  defp filter_by_type(query, ""), do: query
  defp filter_by_type(query, type), do: where(query, [i], i.type == ^type)

  defp filter_by_status(query, nil, _now), do: query
  defp filter_by_status(query, "", _now), do: query
  defp filter_by_status(query, "active", now), do: where(query, [i], i.expires_at > ^now)
  defp filter_by_status(query, "expired", now), do: where(query, [i], i.expires_at <= ^now)
  defp filter_by_status(query, _status, _now), do: query

  defp filter_by_verified(query, nil), do: query
  defp filter_by_verified(query, ""), do: query
  defp filter_by_verified(query, "true"), do: where(query, [i], i.is_verified == true)
  defp filter_by_verified(query, "false"), do: where(query, [i], i.is_verified == false)
  defp filter_by_verified(query, _), do: query

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, ""), do: query
  defp filter_by_search(query, search_term) do
    search_pattern = "%#{search_term}%"
    where(query, [i], ilike(i.description, ^search_pattern) or ilike(i.type, ^search_pattern))
  end

  defp filter_by_date_range(query, nil, nil), do: query
  defp filter_by_date_range(query, start_date, nil) when is_binary(start_date) do
    case DateTime.from_iso8601(start_date) do
      {:ok, datetime, _} -> where(query, [i], i.inserted_at >= ^datetime)
      _ -> query
    end
  end
  defp filter_by_date_range(query, nil, end_date) when is_binary(end_date) do
    case DateTime.from_iso8601(end_date) do
      {:ok, datetime, _} -> where(query, [i], i.inserted_at <= ^datetime)
      _ -> query
    end
  end
  defp filter_by_date_range(query, start_date, end_date) when is_binary(start_date) and is_binary(end_date) do
    with {:ok, start_dt, _} <- DateTime.from_iso8601(start_date),
         {:ok, end_dt, _} <- DateTime.from_iso8601(end_date) do
      where(query, [i], i.inserted_at >= ^start_dt and i.inserted_at <= ^end_dt)
    else
      _ -> query
    end
  end
  defp filter_by_date_range(query, _, _), do: query

  defp apply_sorting(query, sort_by, sort_order) do
    order = if sort_order == "asc", do: :asc, else: :desc

    case sort_by do
      "type" -> order_by(query, [i], [{^order, i.type}])
      "verification_count" -> order_by(query, [i], [{^order, i.verification_count}])
      "is_verified" -> order_by(query, [i], [{^order, i.is_verified}])
      "expires_at" -> order_by(query, [i], [{^order, i.expires_at}])
      _ -> order_by(query, [i], [{^order, i.inserted_at}])
    end
  end

  @doc """
  Gets incident with full details including user, verifications, and flagged content.
  """
  def get_incident_with_details!(id) do
    HotspotApi.Incidents.Incident
    |> Repo.get!(id)
    |> Repo.preload([:user, :verifications, :flagged_content])
  end

  @doc """
  Moderates an incident by performing the specified action.
  Actions: approve, flag, delete
  """
  def moderate_incident(incident_id, action, _admin_id, reason \\ nil) do
    incident = HotspotApi.Incidents.get_incident!(incident_id)

    case action do
      "approve" ->
        # Mark as verified
        HotspotApi.Incidents.update_incident(incident, %{is_verified: true})

      "flag" ->
        # Create flagged content record
        HotspotApi.Moderation.create_flagged_content(%{
          incident_id: incident_id,
          user_id: incident.user_id,
          content_type: "incident",
          flag_reason: reason || "Flagged by admin",
          status: "pending"
        })
        {:ok, incident}

      "delete" ->
        # Delete the incident
        HotspotApi.Incidents.delete_incident(incident)

      _ ->
        {:error, :invalid_action}
    end
  end

  @doc """
  Performs bulk moderation action on multiple incidents.
  """
  def bulk_moderate_incidents(incident_ids, action, _admin_id, reason \\ nil) do
    case action do
      "approve" ->
        # Bulk update to mark as verified
        count = from(i in HotspotApi.Incidents.Incident,
          where: i.id in ^incident_ids
        )
        |> Repo.update_all(set: [is_verified: true, updated_at: DateTime.utc_now()])
        |> elem(0)

        {:ok, count}

      "flag" ->
        # Bulk create flagged content records
        now = DateTime.utc_now()
        flagged_records = Enum.map(incident_ids, fn incident_id ->
          incident = HotspotApi.Incidents.get_incident!(incident_id)
          %{
            incident_id: incident_id,
            user_id: incident.user_id,
            content_type: "incident",
            flag_reason: reason || "Flagged by admin",
            status: "pending",
            inserted_at: now,
            updated_at: now
          }
        end)

        {count, _} = Repo.insert_all(HotspotApi.Moderation.FlaggedContent, flagged_records)
        {:ok, count}

      "delete" ->
        # Bulk delete incidents
        count = from(i in HotspotApi.Incidents.Incident,
          where: i.id in ^incident_ids
        )
        |> Repo.delete_all()
        |> elem(0)

        {:ok, count}

      _ ->
        {:error, :invalid_action}
    end
  end

  @doc """
  Logs an admin action to the audit log.
  """
  def log_audit(admin_user_id, action, resource_type, resource_id, details, ip_address) do
    %HotspotApi.Accounts.AdminAuditLog{}
    |> HotspotApi.Accounts.AdminAuditLog.changeset(%{
      admin_user_id: admin_user_id,
      action: action,
      resource_type: resource_type,
      resource_id: resource_id,
      details: details,
      ip_address: ip_address
    })
    |> Repo.insert()
  end

  defp serialize_location(%Geo.Point{coordinates: {lng, lat}}) do
    %{latitude: lat, longitude: lng}
  end
  defp serialize_location(_), do: nil

  # User Management Functions

  @doc """
  Lists users with pagination, search, and filters for admin panel.
  """
  def list_users_paginated(page, page_size, filters, sort_by, sort_order) do
    # Build base query
    query = from(u in HotspotApi.Accounts.User)

    # Apply filters
    query = apply_user_filters(query, filters)

    # Get total count
    total_count = Repo.aggregate(query, :count, :id)

    # Apply sorting
    query = apply_user_sorting(query, sort_by, sort_order)

    # Apply pagination
    users = query
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> Repo.all()

    total_pages = ceil(total_count / page_size)

    %{
      users: users,
      total_count: total_count,
      page: page,
      page_size: page_size,
      total_pages: total_pages
    }
  end

  defp apply_user_filters(query, filters) do
    query
    |> filter_by_premium_status(filters.is_premium)
    |> filter_by_user_search(filters.search)
    |> filter_by_user_date_range(filters.start_date, filters.end_date)
  end

  defp filter_by_premium_status(query, nil), do: query
  defp filter_by_premium_status(query, ""), do: query
  defp filter_by_premium_status(query, "true"), do: where(query, [u], u.is_premium == true)
  defp filter_by_premium_status(query, "false"), do: where(query, [u], u.is_premium == false)
  defp filter_by_premium_status(query, _), do: query

  defp filter_by_user_search(query, nil), do: query
  defp filter_by_user_search(query, ""), do: query
  defp filter_by_user_search(query, search_term) do
    search_pattern = "%#{search_term}%"
    where(query, [u], ilike(u.phone_number, ^search_pattern))
  end

  defp filter_by_user_date_range(query, nil, nil), do: query
  defp filter_by_user_date_range(query, start_date, nil) when is_binary(start_date) do
    case DateTime.from_iso8601(start_date) do
      {:ok, datetime, _} -> where(query, [u], u.inserted_at >= ^datetime)
      _ -> query
    end
  end
  defp filter_by_user_date_range(query, nil, end_date) when is_binary(end_date) do
    case DateTime.from_iso8601(end_date) do
      {:ok, datetime, _} -> where(query, [u], u.inserted_at <= ^datetime)
      _ -> query
    end
  end
  defp filter_by_user_date_range(query, start_date, end_date) when is_binary(start_date) and is_binary(end_date) do
    with {:ok, start_dt, _} <- DateTime.from_iso8601(start_date),
         {:ok, end_dt, _} <- DateTime.from_iso8601(end_date) do
      where(query, [u], u.inserted_at >= ^start_dt and u.inserted_at <= ^end_dt)
    else
      _ -> query
    end
  end
  defp filter_by_user_date_range(query, _, _), do: query

  defp apply_user_sorting(query, sort_by, sort_order) do
    order = if sort_order == "asc", do: :asc, else: :desc

    case sort_by do
      "phone_number" -> order_by(query, [u], [{^order, u.phone_number}])
      "is_premium" -> order_by(query, [u], [{^order, u.is_premium}])
      "alert_radius" -> order_by(query, [u], [{^order, u.alert_radius}])
      "premium_expires_at" -> order_by(query, [u], [{^order, u.premium_expires_at}])
      _ -> order_by(query, [u], [{^order, u.inserted_at}])
    end
  end

  @doc """
  Gets user with full details including incident history and activity.
  """
  def get_user_with_details!(id) do
    HotspotApi.Accounts.User
    |> Repo.get!(id)
    |> Repo.preload([
      incidents: from(i in HotspotApi.Incidents.Incident, order_by: [desc: i.inserted_at], limit: 50),
      verifications: from(v in HotspotApi.Incidents.IncidentVerification, order_by: [desc: v.inserted_at], limit: 50)
    ])
  end

  @doc """
  Suspends a user account temporarily.
  """
  def suspend_user(user_id, admin_id, reason \\ nil) do
    user = HotspotApi.Accounts.get_user!(user_id)

    # Store suspension info in notification_config
    suspension_data = %{
      suspended: true,
      suspended_at: DateTime.utc_now(),
      suspended_by: admin_id,
      suspension_reason: reason
    }

    updated_config = Map.merge(user.notification_config || %{}, suspension_data)

    case HotspotApi.Accounts.update_user(user, %{notification_config: updated_config}) do
      {:ok, updated_user} ->
        # Log audit
        log_audit(admin_id, "suspend_user", "user", user_id, %{reason: reason}, nil)
        {:ok, updated_user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Bans a user account permanently.
  """
  def ban_user(user_id, admin_id, reason \\ nil) do
    user = HotspotApi.Accounts.get_user!(user_id)

    # Store ban info in notification_config
    ban_data = %{
      banned: true,
      banned_at: DateTime.utc_now(),
      banned_by: admin_id,
      ban_reason: reason
    }

    updated_config = Map.merge(user.notification_config || %{}, ban_data)

    case HotspotApi.Accounts.update_user(user, %{notification_config: updated_config}) do
      {:ok, updated_user} ->
        # Log audit
        log_audit(admin_id, "ban_user", "user", user_id, %{reason: reason}, nil)
        {:ok, updated_user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Grants or revokes premium status for a user.
  """
  def update_user_premium(user_id, is_premium, admin_id, expires_at \\ nil) do
    user = HotspotApi.Accounts.get_user!(user_id)

    attrs = %{
      is_premium: is_premium,
      premium_expires_at: expires_at
    }

    # Update alert radius based on premium status
    attrs = if is_premium do
      # Premium users can have up to 10km radius
      Map.put(attrs, :alert_radius, min(user.alert_radius, 10000))
    else
      # Free users limited to 2km
      Map.put(attrs, :alert_radius, min(user.alert_radius, 2000))
    end

    case HotspotApi.Accounts.update_user(user, attrs) do
      {:ok, updated_user} ->
        # Log audit
        log_audit(admin_id, "update_user_premium", "user", user_id, %{is_premium: is_premium, expires_at: expires_at}, nil)
        {:ok, updated_user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Sends a notification to a specific user.
  """
  def send_user_notification(user_id, admin_id, title, message) do
    _user = HotspotApi.Accounts.get_user!(user_id)

    # Send notification via FCM
    case HotspotApi.Notifications.send_admin_notification(user_id, title, message) do
      :ok ->
        # Log audit
        log_audit(admin_id, "send_user_notification", "user", user_id, %{title: title, message: message}, nil)
        {:ok, %{message: "Notification sent successfully"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets user activity log including incidents reported and verifications made.
  """
  def get_user_activity(user_id, limit \\ 50) do
    _user = HotspotApi.Accounts.get_user!(user_id)

    # Get incidents reported by user
    incidents = from(i in HotspotApi.Incidents.Incident,
      where: i.user_id == ^user_id,
      order_by: [desc: i.inserted_at],
      limit: ^limit
    ) |> Repo.all()

    # Get verifications made by user
    verifications = from(v in HotspotApi.Incidents.IncidentVerification,
      where: v.user_id == ^user_id,
      order_by: [desc: v.inserted_at],
      limit: ^limit,
      preload: [:incident]
    ) |> Repo.all()

    # Combine and sort by timestamp
    activities = []

    activities = activities ++ Enum.map(incidents, fn incident ->
      %{
        id: incident.id,
        type: "incident_reported",
        description: "Reported #{incident.type}",
        incident_type: incident.type,
        incident_id: incident.id,
        location: serialize_location(incident.location),
        created_at: incident.inserted_at
      }
    end)

    activities = activities ++ Enum.map(verifications, fn verification ->
      %{
        id: verification.id,
        type: "incident_verified",
        description: "Verified #{verification.incident.type}",
        incident_type: verification.incident.type,
        incident_id: verification.incident_id,
        location: serialize_location(verification.incident.location),
        created_at: verification.inserted_at
      }
    end)

    # Sort by created_at descending
    activities
    |> Enum.sort_by(& &1.created_at, {:desc, DateTime})
    |> Enum.take(limit)
  end
end
