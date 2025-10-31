defmodule HotspotApiWeb.CommunitiesControllerTest do
  use HotspotApiWeb.ConnCase

  import HotspotApi.AccountsFixtures
  import HotspotApi.IncidentsFixtures

  alias HotspotApi.Communities
  alias HotspotApi.Guardian

  setup do
    user = user_fixture()
    {:ok, token, _claims} = Guardian.encode_and_sign(user, %{}, token_type: "access")

    %{user: user, token: token}
  end

  describe "GET /api/communities" do
    test "lists all public community groups", %{conn: conn, token: token, user: user} do
      # Create public groups
      {:ok, group1} = Communities.create_group(%{
        name: "Public Group 1",
        description: "Test",
        is_public: true,
        created_by_id: user.id
      })

      {:ok, _group2} = Communities.create_group(%{
        name: "Public Group 2",
        description: "Test",
        is_public: true,
        created_by_id: user.id
      })

      # Create private group (should not appear)
      {:ok, _private_group} = Communities.create_group(%{
        name: "Private Group",
        description: "Test",
        is_public: false,
        created_by_id: user.id
      })

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/communities")

      assert %{"data" => groups} = json_response(conn, 200)
      assert length(groups) == 2
      assert Enum.all?(groups, fn g -> g["is_public"] == true end)
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/communities")
      assert json_response(conn, 401)
    end
  end

  describe "GET /api/communities/nearby" do
    @tag :skip
    test "lists groups near specified location", %{conn: conn, token: token, user: user} do
      # Create nearby group
      {:ok, nearby_group} = Communities.create_group(%{
        name: "Nearby Group",
        description: "Test",
        is_public: true,
        center_latitude: -26.2041,
        center_longitude: 28.0473,
        radius_meters: 5000,
        created_by_id: user.id
      })

      # Create far group
      {:ok, _far_group} = Communities.create_group(%{
        name: "Far Group",
        description: "Test",
        is_public: true,
        center_latitude: -26.5041,
        center_longitude: 28.5473,
        radius_meters: 5000,
        created_by_id: user.id
      })

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/communities/nearby?latitude=-26.2041&longitude=28.0473&radius=10000")

      assert %{"data" => groups} = json_response(conn, 200)
      assert length(groups) == 1
      assert hd(groups)["id"] == nearby_group.id
    end

    @tag :skip
    test "requires latitude and longitude parameters", %{conn: conn, token: token} do
      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/communities/nearby")

      assert json_response(conn, 400)
    end
  end

  describe "GET /api/communities/my-groups" do
    test "lists groups user is member of", %{conn: conn, token: token, user: user} do
      other_user = user_fixture(%{phone_number: "+27987654321"})

      # Create groups where user is member
      {:ok, group1} = Communities.create_group(%{
        name: "My Group 1",
        description: "Test",
        is_public: true,
        created_by_id: user.id
      })

      {:ok, group2} = Communities.create_group(%{
        name: "My Group 2",
        description: "Test",
        is_public: true,
        created_by_id: user.id
      })

      # Create group where user is not member
      {:ok, _other_group} = Communities.create_group(%{
        name: "Other Group",
        description: "Test",
        is_public: true,
        created_by_id: other_user.id
      })

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/communities/my-groups")

      assert %{"data" => groups} = json_response(conn, 200)
      assert length(groups) == 2
      group_ids = Enum.map(groups, & &1["id"])
      assert group1.id in group_ids
      assert group2.id in group_ids
    end
  end

  describe "GET /api/communities/:id" do
    test "returns group details", %{conn: conn, token: token, user: user} do
      {:ok, group} = Communities.create_group(%{
        name: "Test Group",
        description: "Test Description",
        is_public: true,
        created_by_id: user.id
      })

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/communities/#{group.id}")

      assert %{"data" => group_data} = json_response(conn, 200)
      assert group_data["id"] == group.id
      assert group_data["name"] == "Test Group"
      assert group_data["description"] == "Test Description"
      assert group_data["member_count"] == 1
    end

    @tag :skip
    test "returns 404 for non-existent group", %{conn: conn, token: token} do
      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/communities/00000000-0000-0000-0000-000000000000")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/communities" do
    test "creates a new group", %{conn: conn, token: token, user: user} do
      group_params = %{
        name: "New Group",
        description: "A new community group",
        is_public: true,
        center_latitude: -26.2041,
        center_longitude: 28.0473,
        radius_meters: 5000
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/communities", group_params)

      assert %{"data" => group_data} = json_response(conn, 201)
      assert group_data["name"] == "New Group"
      assert group_data["description"] == "A new community group"
      assert group_data["member_count"] == 1

      # Verify creator is admin member
      assert Communities.can_moderate?(group_data["id"], user.id)
    end

    test "returns error with invalid data", %{conn: conn, token: token} do
      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/communities", %{name: nil})

      assert json_response(conn, 422)
    end
  end

  describe "PUT /api/communities/:id" do
    test "updates group details", %{conn: conn, token: token, user: user} do
      {:ok, group} = Communities.create_group(%{
        name: "Original Name",
        description: "Original Description",
        is_public: true,
        created_by_id: user.id
      })

      update_params = %{
        name: "Updated Name",
        description: "Updated Description"
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put(~p"/api/communities/#{group.id}", update_params)

      assert %{"data" => group_data} = json_response(conn, 200)
      assert group_data["name"] == "Updated Name"
      assert group_data["description"] == "Updated Description"
    end

    test "returns error if user is not admin", %{conn: conn, user: creator} do
      other_user = user_fixture(%{phone_number: "+27987654321"})
      {:ok, other_token, _} = Guardian.encode_and_sign(other_user, %{}, token_type: "access")

      {:ok, group} = Communities.create_group(%{
        name: "Test Group",
        description: "Test",
        is_public: true,
        created_by_id: creator.id
      })

      conn = conn
      |> put_req_header("authorization", "Bearer #{other_token}")
      |> put(~p"/api/communities/#{group.id}", %{name: "Hacked Name"})

      assert json_response(conn, 403)
    end
  end

  describe "DELETE /api/communities/:id" do
    test "deletes group", %{conn: conn, token: token, user: user} do
      {:ok, group} = Communities.create_group(%{
        name: "To Delete",
        description: "Test",
        is_public: true,
        created_by_id: user.id
      })

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> delete(~p"/api/communities/#{group.id}")

      assert response(conn, 204)
      assert_raise Ecto.NoResultsError, fn -> Communities.get_group!(group.id) end
    end

    test "returns error if user is not admin", %{conn: conn, user: creator} do
      other_user = user_fixture(%{phone_number: "+27987654321"})
      {:ok, other_token, _} = Guardian.encode_and_sign(other_user, %{}, token_type: "access")

      {:ok, group} = Communities.create_group(%{
        name: "Test Group",
        description: "Test",
        is_public: true,
        created_by_id: creator.id
      })

      conn = conn
      |> put_req_header("authorization", "Bearer #{other_token}")
      |> delete(~p"/api/communities/#{group.id}")

      assert json_response(conn, 403)
    end
  end

  describe "POST /api/communities/:id/join" do
    test "adds user to group", %{conn: conn, token: token, user: joiner} do
      creator = user_fixture(%{phone_number: "+27987654321"})

      {:ok, group} = Communities.create_group(%{
        name: "Test Group",
        description: "Test",
        is_public: true,
        created_by_id: creator.id
      })

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/communities/#{group.id}/join")

      assert %{"message" => _msg} = json_response(conn, 200)
      assert Communities.member?(group.id, joiner.id)

      # Verify member count increased
      updated_group = Communities.get_group!(group.id)
      assert updated_group.member_count == 2
    end

    test "returns error if already a member", %{conn: conn, token: token, user: user} do
      {:ok, group} = Communities.create_group(%{
        name: "Test Group",
        description: "Test",
        is_public: true,
        created_by_id: user.id
      })

      # User is already a member (creator)
      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/communities/#{group.id}/join")

      assert json_response(conn, 422)
    end
  end

  describe "POST /api/communities/:id/leave" do
    test "removes user from group", %{conn: conn, token: token, user: member} do
      creator = user_fixture(%{phone_number: "+27987654321"})

      {:ok, group} = Communities.create_group(%{
        name: "Test Group",
        description: "Test",
        is_public: true,
        created_by_id: creator.id
      })

      # Join first
      {:ok, _} = Communities.join_group(group.id, member.id)

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/communities/#{group.id}/leave")

      assert %{"message" => _msg} = json_response(conn, 200)
      refute Communities.member?(group.id, member.id)
    end

    test "returns error if not a member", %{conn: conn, token: token, user: user} do
      other_user = user_fixture(%{phone_number: "+27987654321"})

      {:ok, group} = Communities.create_group(%{
        name: "Test Group",
        description: "Test",
        is_public: true,
        created_by_id: other_user.id
      })

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/communities/#{group.id}/leave")

      assert json_response(conn, 422)
    end
  end

  describe "GET /api/communities/:id/incidents" do
    test "returns incidents for group", %{conn: conn, token: token, user: user} do
      {:ok, group} = Communities.create_group(%{
        name: "Test Group",
        description: "Test",
        is_public: true,
        center_latitude: -26.2041,
        center_longitude: 28.0473,
        radius_meters: 5000,
        created_by_id: user.id
      })

      # Create incident within group radius
      incident = incident_fixture(%{
        user_id: user.id,
        latitude: -26.2041,
        longitude: 28.0473
      })

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/communities/#{group.id}/incidents")

      assert %{"data" => incidents, "pagination" => _pagination} = json_response(conn, 200)
      assert length(incidents) >= 1
      assert Enum.any?(incidents, fn i -> i["id"] == incident.id end)
    end

    test "filters incidents by type", %{conn: conn, token: token, user: user} do
      {:ok, group} = Communities.create_group(%{
        name: "Test Group",
        description: "Test",
        is_public: true,
        center_latitude: -26.2041,
        center_longitude: 28.0473,
        radius_meters: 5000,
        created_by_id: user.id
      })

      hijacking = incident_fixture(%{
        user_id: user.id,
        type: "hijacking",
        latitude: -26.2041,
        longitude: 28.0473
      })

      _mugging = incident_fixture(%{
        user_id: user.id,
        type: "mugging",
        latitude: -26.2041,
        longitude: 28.0473
      })

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/communities/#{group.id}/incidents?type=hijacking")

      assert %{"data" => incidents} = json_response(conn, 200)
      assert Enum.all?(incidents, fn i -> i["type"] == "hijacking" end)
    end

    test "supports pagination", %{conn: conn, token: token, user: user} do
      {:ok, group} = Communities.create_group(%{
        name: "Test Group",
        description: "Test",
        is_public: true,
        center_latitude: -26.2041,
        center_longitude: 28.0473,
        radius_meters: 5000,
        created_by_id: user.id
      })

      # Create multiple incidents
      for _ <- 1..15 do
        incident_fixture(%{
          user_id: user.id,
          latitude: -26.2041,
          longitude: 28.0473
        })
      end

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/communities/#{group.id}/incidents?page=1&page_size=10")

      assert %{"data" => incidents, "pagination" => pagination} = json_response(conn, 200)
      assert length(incidents) == 10
      assert pagination["page"] == 1
      assert pagination["total_count"] >= 15
    end
  end

  describe "GET /api/communities/:id/members" do
    test "returns list of group members", %{conn: conn, token: token, user: creator} do
      member1 = user_fixture(%{phone_number: "+27987654321"})
      member2 = user_fixture(%{phone_number: "+27987654322"})

      {:ok, group} = Communities.create_group(%{
        name: "Test Group",
        description: "Test",
        is_public: true,
        created_by_id: creator.id
      })

      {:ok, _} = Communities.join_group(group.id, member1.id)
      {:ok, _} = Communities.join_group(group.id, member2.id)

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/communities/#{group.id}/members")

      assert %{"data" => members} = json_response(conn, 200)
      assert length(members) == 3  # creator + 2 members

      # Verify creator is admin
      creator_member = Enum.find(members, fn m -> m["user_id"] == creator.id end)
      assert creator_member["role"] == "admin"
    end
  end

  describe "PUT /api/communities/:id/members/:user_id/role" do
    test "updates member role", %{conn: conn, token: token, user: admin} do
      member = user_fixture(%{phone_number: "+27987654321"})

      {:ok, group} = Communities.create_group(%{
        name: "Test Group",
        description: "Test",
        is_public: true,
        created_by_id: admin.id
      })

      {:ok, _} = Communities.join_group(group.id, member.id)

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put(~p"/api/communities/#{group.id}/members/#{member.id}/role", %{role: "moderator"})

      assert %{"message" => _msg} = json_response(conn, 200)

      # Verify role was updated
      updated_member = Communities.get_group_member(group.id, member.id)
      assert updated_member.role == "moderator"
    end

    test "returns error if user is not admin", %{conn: conn, user: creator} do
      member = user_fixture(%{phone_number: "+27987654321"})
      non_admin = user_fixture(%{phone_number: "+27987654322"})
      {:ok, non_admin_token, _} = Guardian.encode_and_sign(non_admin, %{}, token_type: "access")

      {:ok, group} = Communities.create_group(%{
        name: "Test Group",
        description: "Test",
        is_public: true,
        created_by_id: creator.id
      })

      {:ok, _} = Communities.join_group(group.id, member.id)
      {:ok, _} = Communities.join_group(group.id, non_admin.id)

      conn = conn
      |> put_req_header("authorization", "Bearer #{non_admin_token}")
      |> put(~p"/api/communities/#{group.id}/members/#{member.id}/role", %{role: "moderator"})

      assert json_response(conn, 403)
    end
  end
end
