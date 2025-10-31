defmodule HotspotApiWeb.CommunitiesController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Communities
  alias HotspotApi.Guardian

  action_fallback HotspotApiWeb.FallbackController

  # ============================================================================
  # Community Groups
  # ============================================================================

  @doc """
  List public groups or groups near a location
  """
  def index(conn, %{"latitude" => lat, "longitude" => lng} = params) do
    radius = Map.get(params, "radius", "10000") |> String.to_integer()
    groups = Communities.list_nearby_groups(lat, lng, radius)
    render(conn, :index, groups: groups)
  end

  def index(conn, _params) do
    groups = Communities.list_public_groups()
    render(conn, :index, groups: groups)
  end

  @doc """
  List groups that the current user is a member of
  """
  def my_groups(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    groups = Communities.list_user_groups(user.id)
    render(conn, :index, groups: groups)
  end

  @doc """
  Get a single group
  """
  def show(conn, %{"id" => id}) do
    group = Communities.get_group!(id)
    render(conn, :show, group: group)
  end

  @doc """
  Create a new group
  """
  def create(conn, %{"group" => group_params}) do
    user = Guardian.Plug.current_resource(conn)

    attrs =
      group_params
      |> Map.put("created_by_id", user.id)

    case Communities.create_group(attrs) do
      {:ok, group} ->
        conn
        |> put_status(:created)
        |> render(:show, group: group)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: HotspotApiWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  @doc """
  Update a group (admin only)
  """
  def update(conn, %{"id" => id, "group" => group_params}) do
    user = Guardian.Plug.current_resource(conn)
    group = Communities.get_group!(id)

    # Check if user is admin
    unless Communities.can_moderate?(id, user.id) do
      conn
      |> put_status(:forbidden)
      |> put_view(json: HotspotApiWeb.ErrorJSON)
      |> render(:"403")
      |> halt()
    else
      case Communities.update_group(group, group_params) do
        {:ok, group} ->
          render(conn, :show, group: group)

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(json: HotspotApiWeb.ChangesetJSON)
          |> render(:error, changeset: changeset)
      end
    end
  end

  @doc """
  Delete a group (admin only)
  """
  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)
    group = Communities.get_group!(id)

    # Check if user is admin
    unless Communities.can_moderate?(id, user.id) do
      conn
      |> put_status(:forbidden)
      |> put_view(json: HotspotApiWeb.ErrorJSON)
      |> render(:"403")
      |> halt()
    else
      with {:ok, _group} <- Communities.delete_group(group) do
        send_resp(conn, :no_content, "")
      end
    end
  end

  # ============================================================================
  # Group Membership
  # ============================================================================

  @doc """
  Join a group
  """
  def join(conn, %{"id" => group_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Communities.join_group(group_id, user.id) do
      {:ok, member} ->
        conn
        |> put_status(:created)
        |> render(:member, member: member)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: HotspotApiWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  @doc """
  Leave a group
  """
  def leave(conn, %{"id" => group_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Communities.leave_group(group_id, user.id) do
      {:ok, :ok} ->
        send_resp(conn, :no_content, "")

      {:error, :not_a_member} ->
        conn
        |> put_status(:not_found)
        |> put_view(json: HotspotApiWeb.ErrorJSON)
        |> render(:"404")
    end
  end

  @doc """
  List group members
  """
  def members(conn, %{"id" => group_id}) do
    members = Communities.list_group_members(group_id)
    render(conn, :members, members: members)
  end

  @doc """
  Update member role (admin only)
  """
  def update_member_role(conn, %{"id" => group_id, "user_id" => target_user_id, "role" => role}) do
    user = Guardian.Plug.current_resource(conn)

    # Check if current user is admin
    unless Communities.can_moderate?(group_id, user.id) do
      conn
      |> put_status(:forbidden)
      |> put_view(json: HotspotApiWeb.ErrorJSON)
      |> render(:"403")
      |> halt()
    else
      case Communities.update_member_role(group_id, target_user_id, role) do
        {:ok, member} ->
          render(conn, :member, member: member)

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> put_view(json: HotspotApiWeb.ErrorJSON)
          |> render(:"404")

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(json: HotspotApiWeb.ChangesetJSON)
          |> render(:error, changeset: changeset)
      end
    end
  end

  @doc """
  Update notification preferences for a group
  """
  def update_notifications(conn, %{"id" => group_id, "enabled" => enabled}) do
    user = Guardian.Plug.current_resource(conn)

    # Check if user is a member
    unless Communities.member?(group_id, user.id) do
      conn
      |> put_status(:forbidden)
      |> put_view(json: HotspotApiWeb.ErrorJSON)
      |> render(:"403")
      |> halt()
    else
      case Communities.update_notification_preferences(group_id, user.id, enabled) do
        {:ok, member} ->
          render(conn, :member, member: member)

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> put_view(json: HotspotApiWeb.ErrorJSON)
          |> render(:"404")

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(json: HotspotApiWeb.ChangesetJSON)
          |> render(:error, changeset: changeset)
      end
    end
  end

  # ============================================================================
  # Group Incidents
  # ============================================================================

  @doc """
  List incidents for a group
  """
  def incidents(conn, %{"id" => group_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    # Check if user is a member
    unless Communities.member?(group_id, user.id) do
      conn
      |> put_status(:forbidden)
      |> put_view(json: HotspotApiWeb.ErrorJSON)
      |> render(:"403")
      |> halt()
    else
      page = Map.get(params, "page", "1") |> String.to_integer()
      page_size = Map.get(params, "page_size", "20") |> String.to_integer()
      type_filter = Map.get(params, "type")

      result =
        Communities.list_group_incidents(group_id,
          page: page,
          page_size: page_size,
          type: type_filter
        )

      render(conn, :incidents, result)
    end
  end
end
