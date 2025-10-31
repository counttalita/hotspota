defmodule HotspotApiWeb.CommunitiesJSON do
  alias HotspotApi.Communities.{CommunityGroup, GroupMember}
  alias HotspotApi.Incidents.Incident

  @doc """
  Renders a list of groups.
  """
  def index(%{groups: groups}) do
    %{data: for(group <- groups, do: data(group))}
  end

  @doc """
  Renders a single group.
  """
  def show(%{group: group}) do
    %{data: data(group)}
  end

  @doc """
  Renders a single member.
  """
  def member(%{member: member}) do
    %{data: member_data(member)}
  end

  @doc """
  Renders a list of members.
  """
  def members(%{members: members}) do
    %{data: for(member <- members, do: member_data(member))}
  end

  @doc """
  Renders paginated incidents.
  """
  def incidents(%{incidents: incidents, page: page, page_size: page_size, total_count: total_count, total_pages: total_pages}) do
    %{
      data: for(incident <- incidents, do: incident_data(incident)),
      pagination: %{
        page: page,
        page_size: page_size,
        total_count: total_count,
        total_pages: total_pages
      }
    }
  end

  defp data(%CommunityGroup{} = group) do
    %{
      id: group.id,
      name: group.name,
      description: group.description,
      location_name: group.location_name,
      center_latitude: group.center_latitude,
      center_longitude: group.center_longitude,
      radius_meters: group.radius_meters,
      is_public: group.is_public,
      member_count: group.member_count,
      created_by_id: group.created_by_id,
      inserted_at: group.inserted_at,
      updated_at: group.updated_at
    }
  end

  defp member_data(%GroupMember{} = member) do
    base = %{
      id: member.id,
      group_id: member.group_id,
      user_id: member.user_id,
      role: member.role,
      joined_at: member.joined_at,
      notifications_enabled: member.notifications_enabled,
      inserted_at: member.inserted_at
    }

    # Include user data if preloaded
    case member.user do
      %Ecto.Association.NotLoaded{} -> base
      user -> Map.put(base, :user, user_data(user))
    end
  end

  defp user_data(user) do
    %{
      id: user.id,
      phone_number: user.phone_number,
      is_premium: user.is_premium
    }
  end

  defp incident_data(%Incident{} = incident) do
    %{
      id: incident.id,
      type: incident.type,
      latitude: incident.location.coordinates |> elem(1),
      longitude: incident.location.coordinates |> elem(0),
      description: incident.description,
      photo_url: incident.photo_url,
      verification_count: incident.verification_count,
      is_verified: incident.is_verified,
      inserted_at: incident.inserted_at,
      expires_at: incident.expires_at
    }
  end
end
