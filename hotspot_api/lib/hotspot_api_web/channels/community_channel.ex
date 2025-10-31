defmodule HotspotApiWeb.CommunityChannel do
  use HotspotApiWeb, :channel

  alias HotspotApi.Communities
  alias HotspotApi.Guardian

  @impl true
  def join("community:" <> group_id, _payload, socket) do
    # Get user_id from socket assigns (set in UserSocket.connect/3)
    case socket.assigns[:user_id] do
      nil ->
        {:error, %{reason: "unauthorized"}}

      user_id ->
        # Check if user is a member of the group
        if Communities.member?(group_id, user_id) do
          {:ok, assign(socket, :group_id, group_id)}
        else
          {:error, %{reason: "not_a_member"}}
        end
    end
  end

  @impl true
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{status: "pong"}}, socket}
  end

  @doc """
  Broadcast a new incident to all group members.
  Called when an incident is created within the group's area or explicitly added to the group.
  """
  def broadcast_new_incident(group_id, incident) do
    HotspotApiWeb.Endpoint.broadcast("community:#{group_id}", "incident:new", %{
      incident: %{
        id: incident.id,
        type: incident.type,
        latitude: incident.location.coordinates |> elem(1),
        longitude: incident.location.coordinates |> elem(0),
        description: incident.description,
        verification_count: incident.verification_count,
        is_verified: incident.is_verified,
        inserted_at: incident.inserted_at
      }
    })
  end

  @doc """
  Broadcast when a member joins the group.
  """
  def broadcast_member_joined(group_id, member) do
    HotspotApiWeb.Endpoint.broadcast("community:#{group_id}", "member:joined", %{
      member: %{
        id: member.id,
        user_id: member.user_id,
        role: member.role,
        joined_at: member.joined_at
      }
    })
  end

  @doc """
  Broadcast when a member leaves the group.
  """
  def broadcast_member_left(group_id, user_id) do
    HotspotApiWeb.Endpoint.broadcast("community:#{group_id}", "member:left", %{
      user_id: user_id
    })
  end
end
