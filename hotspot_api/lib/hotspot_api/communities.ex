defmodule HotspotApi.Communities do
  @moduledoc """
  The Communities context for managing neighborhood groups and community features.
  """

  import Ecto.Query, warn: false
  import Geo.PostGIS
  alias HotspotApi.Repo

  alias HotspotApi.Communities.{CommunityGroup, GroupMember, GroupIncident}
  alias HotspotApi.Incidents.Incident

  # ============================================================================
  # Community Groups
  # ============================================================================

  @doc """
  Returns the list of public community groups.
  """
  def list_public_groups do
    CommunityGroup
    |> where([g], g.is_public == true)
    |> order_by([g], desc: g.member_count)
    |> Repo.all()
  end

  @doc """
  Returns community groups near a given location.
  """
  def list_nearby_groups(latitude, longitude, radius_meters \\ 10000) do
    CommunityGroup
    |> where([g], g.is_public == true)
    |> where([g], not is_nil(g.center_latitude) and not is_nil(g.center_longitude))
    |> Repo.all()
    |> Enum.filter(fn group ->
      distance = calculate_distance(
        group.center_latitude,
        group.center_longitude,
        latitude,
        longitude
      )
      distance <= radius_meters
    end)
    |> Enum.sort_by(fn group ->
      calculate_distance(
        group.center_latitude,
        group.center_longitude,
        latitude,
        longitude
      )
    end)
  end

  @doc """
  Returns groups that a user is a member of.
  """
  def list_user_groups(user_id) do
    query =
      from g in CommunityGroup,
        join: m in GroupMember,
        on: m.group_id == g.id,
        where: m.user_id == ^user_id,
        order_by: [desc: g.inserted_at],
        preload: [group_members: m]

    Repo.all(query)
  end

  @doc """
  Gets a single community group.
  """
  def get_group!(id) do
    CommunityGroup
    |> preload([:created_by, :group_members])
    |> Repo.get!(id)
  end

  @doc """
  Gets a single community group with optional preloads.
  """
  def get_group(id, preloads \\ []) do
    CommunityGroup
    |> preload(^preloads)
    |> Repo.get(id)
  end

  @doc """
  Creates a community group and automatically adds the creator as an admin member.
  """
  def create_group(attrs) do
    Repo.transaction(fn ->
      # Create the group
      group_result =
        %CommunityGroup{}
        |> CommunityGroup.changeset(attrs)
        |> Repo.insert()

      case group_result do
        {:ok, group} ->
          # Add creator as admin member
          creator_id = Map.get(attrs, "created_by_id") || Map.get(attrs, :created_by_id)

          member_result =
            %GroupMember{}
            |> GroupMember.changeset(%{
              group_id: group.id,
              user_id: creator_id,
              role: "admin"
            })
            |> Repo.insert()

          case member_result do
            {:ok, _member} ->
              # Update member count
              group
              |> CommunityGroup.changeset(%{member_count: 1})
              |> Repo.update!()

            {:error, changeset} ->
              Repo.rollback(changeset)
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Updates a community group.
  """
  def update_group(%CommunityGroup{} = group, attrs) do
    group
    |> CommunityGroup.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a community group.
  """
  def delete_group(%CommunityGroup{} = group) do
    Repo.delete(group)
  end

  # ============================================================================
  # Group Members
  # ============================================================================

  @doc """
  Adds a user to a group.
  """
  def join_group(group_id, user_id, role \\ "member") do
    result =
      Repo.transaction(fn ->
        member_result =
          %GroupMember{}
          |> GroupMember.changeset(%{
            group_id: group_id,
            user_id: user_id,
            role: role
          })
          |> Repo.insert()

        case member_result do
          {:ok, member} ->
            # Increment member count
            group = Repo.get!(CommunityGroup, group_id)

            group
            |> CommunityGroup.changeset(%{member_count: group.member_count + 1})
            |> Repo.update!()

            member

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)

    # Broadcast member joined event
    case result do
      {:ok, member} ->
        HotspotApiWeb.CommunityChannel.broadcast_member_joined(group_id, member)
        result

      error ->
        error
    end
  end

  @doc """
  Removes a user from a group.
  """
  def leave_group(group_id, user_id) do
    result =
      Repo.transaction(fn ->
        member =
          GroupMember
          |> where([m], m.group_id == ^group_id and m.user_id == ^user_id)
          |> Repo.one()

        case member do
          nil ->
            Repo.rollback(:not_a_member)

          member ->
            Repo.delete!(member)

            # Decrement member count
            group = Repo.get!(CommunityGroup, group_id)

            group
            |> CommunityGroup.changeset(%{member_count: max(group.member_count - 1, 0)})
            |> Repo.update!()

            :ok
        end
      end)

    # Broadcast member left event
    case result do
      {:ok, :ok} ->
        HotspotApiWeb.CommunityChannel.broadcast_member_left(group_id, user_id)
        result

      error ->
        error
    end
  end

  @doc """
  Updates a group member's role.
  """
  def update_member_role(group_id, user_id, new_role) do
    member =
      GroupMember
      |> where([m], m.group_id == ^group_id and m.user_id == ^user_id)
      |> Repo.one()

    case member do
      nil -> {:error, :not_found}
      member ->
        member
        |> GroupMember.changeset(%{role: new_role})
        |> Repo.update()
    end
  end

  @doc """
  Gets a group member record.
  """
  def get_group_member(group_id, user_id) do
    GroupMember
    |> where([m], m.group_id == ^group_id and m.user_id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Lists all members of a group.
  """
  def list_group_members(group_id) do
    GroupMember
    |> where([m], m.group_id == ^group_id)
    |> preload(:user)
    |> order_by([m], asc: m.joined_at)
    |> Repo.all()
  end

  @doc """
  Checks if a user is a member of a group.
  """
  def member?(group_id, user_id) do
    GroupMember
    |> where([m], m.group_id == ^group_id and m.user_id == ^user_id)
    |> Repo.exists?()
  end

  @doc """
  Checks if a user is an admin or moderator of a group.
  """
  def can_moderate?(group_id, user_id) do
    GroupMember
    |> where([m], m.group_id == ^group_id and m.user_id == ^user_id)
    |> where([m], m.role in ["admin", "moderator"])
    |> Repo.exists?()
  end

  @doc """
  Updates notification preferences for a group member.
  """
  def update_notification_preferences(group_id, user_id, enabled) do
    member =
      GroupMember
      |> where([m], m.group_id == ^group_id and m.user_id == ^user_id)
      |> Repo.one()

    case member do
      nil -> {:error, :not_found}
      member ->
        member
        |> GroupMember.changeset(%{notifications_enabled: enabled})
        |> Repo.update()
    end
  end

  # ============================================================================
  # Group Incidents
  # ============================================================================

  @doc """
  Links an incident to a group (makes it visible in group feed).
  """
  def add_incident_to_group(group_id, incident_id) do
    result =
      %GroupIncident{}
      |> GroupIncident.changeset(%{group_id: group_id, incident_id: incident_id})
      |> Repo.insert()

    # Broadcast to group members
    case result do
      {:ok, _group_incident} ->
        incident = HotspotApi.Incidents.get_incident!(incident_id)
        HotspotApiWeb.CommunityChannel.broadcast_new_incident(group_id, incident)
        result

      error ->
        error
    end
  end

  @doc """
  Lists incidents for a specific group.
  Returns incidents that are either:
  1. Explicitly linked to the group via group_incidents table
  2. Within the group's geographic radius (if group has location)
  """
  def list_group_incidents(group_id, opts \\ []) do
    group = Repo.get!(CommunityGroup, group_id)
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 20)
    type_filter = Keyword.get(opts, :type)

    # Get explicitly linked incidents
    linked_incident_ids =
      from(gi in GroupIncident,
        where: gi.group_id == ^group_id,
        select: gi.incident_id
      )
      |> Repo.all()

    # Build base query
    now = DateTime.utc_now()

    query =
      from i in Incident,
        where: i.expires_at > ^now

    # Add filter for linked incidents OR incidents within group radius
    query =
      if group.center_latitude && group.center_longitude && group.radius_meters do
        point = %Geo.Point{
          coordinates: {group.center_longitude, group.center_latitude},
          srid: 4326
        }

        from i in query,
          where:
            i.id in ^linked_incident_ids or
              st_dwithin_in_meters(i.location, ^point, ^group.radius_meters)
      else
        from i in query, where: i.id in ^linked_incident_ids
      end

    # Apply type filter
    query =
      if type_filter && type_filter != "all" do
        from i in query, where: i.type == ^type_filter
      else
        query
      end

    # Get total count
    total_count = Repo.aggregate(query, :count, :id)

    # Apply pagination
    incidents =
      query
      |> order_by([i], desc: i.inserted_at)
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> Repo.all()

    %{
      incidents: incidents,
      page: page,
      page_size: page_size,
      total_count: total_count,
      total_pages: ceil(total_count / page_size)
    }
  end

  @doc """
  Removes an incident from a group.
  """
  def remove_incident_from_group(group_id, incident_id) do
    GroupIncident
    |> where([gi], gi.group_id == ^group_id and gi.incident_id == ^incident_id)
    |> Repo.delete_all()
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  # Calculate distance in meters using Haversine formula
  defp calculate_distance(lat1, lng1, lat2, lng2) do
    r = 6371000 # Earth's radius in meters

    phi1 = lat1 * :math.pi() / 180
    phi2 = lat2 * :math.pi() / 180
    delta_phi = (lat2 - lat1) * :math.pi() / 180
    delta_lambda = (lng2 - lng1) * :math.pi() / 180

    a =
      :math.sin(delta_phi / 2) * :math.sin(delta_phi / 2) +
        :math.cos(phi1) * :math.cos(phi2) *
          :math.sin(delta_lambda / 2) * :math.sin(delta_lambda / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))

    round(r * c)
  end
end
