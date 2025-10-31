defmodule HotspotApi.CommunitiesTest do
  use HotspotApi.DataCase

  import HotspotApi.AccountsFixtures
  import HotspotApi.IncidentsFixtures

  alias HotspotApi.Communities
  alias HotspotApi.Communities.{CommunityGroup, GroupMember}

  describe "community groups" do
    @valid_group_attrs %{
      name: "Test Neighborhood Watch",
      description: "A test community group",
      is_public: true,
      center_latitude: -26.2041,
      center_longitude: 28.0473,
      radius_meters: 5000
    }

    test "list_public_groups/0 returns all public groups" do
      user = user_fixture()
      {:ok, group1} = Communities.create_group(Map.put(@valid_group_attrs, :created_by_id, user.id))
      {:ok, group2} = Communities.create_group(Map.merge(@valid_group_attrs, %{name: "Group 2", created_by_id: user.id}))

      # Create a private group
      {:ok, _private_group} = Communities.create_group(Map.merge(@valid_group_attrs, %{
        name: "Private Group",
        is_public: false,
        created_by_id: user.id
      }))

      public_groups = Communities.list_public_groups()

      assert length(public_groups) == 2
      assert Enum.any?(public_groups, fn g -> g.id == group1.id end)
      assert Enum.any?(public_groups, fn g -> g.id == group2.id end)
    end

    test "list_nearby_groups/3 returns groups within radius" do
      user = user_fixture()

      # Create group at specific location
      {:ok, nearby_group} = Communities.create_group(Map.merge(@valid_group_attrs, %{
        center_latitude: -26.2041,
        center_longitude: 28.0473,
        created_by_id: user.id
      }))

      # Create group far away
      {:ok, _far_group} = Communities.create_group(Map.merge(@valid_group_attrs, %{
        name: "Far Group",
        center_latitude: -26.5041,
        center_longitude: 28.5473,
        created_by_id: user.id
      }))

      # Search near first group
      nearby = Communities.list_nearby_groups(-26.2041, 28.0473, 10000)

      assert length(nearby) == 1
      assert hd(nearby).id == nearby_group.id
    end

    test "list_user_groups/1 returns groups user is member of" do
      user = user_fixture()
      other_user = user_fixture(%{phone_number: "+27987654321"})

      {:ok, group1} = Communities.create_group(Map.put(@valid_group_attrs, :created_by_id, user.id))
      {:ok, group2} = Communities.create_group(Map.merge(@valid_group_attrs, %{name: "Group 2", created_by_id: user.id}))
      {:ok, _other_group} = Communities.create_group(Map.merge(@valid_group_attrs, %{name: "Other Group", created_by_id: other_user.id}))

      user_groups = Communities.list_user_groups(user.id)

      assert length(user_groups) == 2
      assert Enum.any?(user_groups, fn g -> g.id == group1.id end)
      assert Enum.any?(user_groups, fn g -> g.id == group2.id end)
    end

    test "get_group!/1 returns the group with given id" do
      user = user_fixture()
      {:ok, group} = Communities.create_group(Map.put(@valid_group_attrs, :created_by_id, user.id))

      fetched_group = Communities.get_group!(group.id)
      assert fetched_group.id == group.id
      assert fetched_group.name == @valid_group_attrs.name
    end

    test "create_group/1 with valid data creates a group and adds creator as admin" do
      user = user_fixture()
      attrs = Map.put(@valid_group_attrs, :created_by_id, user.id)

      assert {:ok, %CommunityGroup{} = group} = Communities.create_group(attrs)
      assert group.name == "Test Neighborhood Watch"
      assert group.description == "A test community group"
      assert group.is_public == true
      assert group.member_count == 1
      assert group.created_by_id == user.id

      # Verify creator is added as admin member
      member = Communities.get_group_member(group.id, user.id)
      assert member != nil
      assert member.role == "admin"
    end

    test "create_group/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Communities.create_group(%{name: nil})
    end

    test "update_group/2 with valid data updates the group" do
      user = user_fixture()
      {:ok, group} = Communities.create_group(Map.put(@valid_group_attrs, :created_by_id, user.id))

      update_attrs = %{name: "Updated Name", description: "Updated description"}
      assert {:ok, %CommunityGroup{} = updated_group} = Communities.update_group(group, update_attrs)
      assert updated_group.name == "Updated Name"
      assert updated_group.description == "Updated description"
    end

    test "delete_group/1 deletes the group" do
      user = user_fixture()
      {:ok, group} = Communities.create_group(Map.put(@valid_group_attrs, :created_by_id, user.id))

      assert {:ok, %CommunityGroup{}} = Communities.delete_group(group)
      assert_raise Ecto.NoResultsError, fn -> Communities.get_group!(group.id) end
    end
  end

  describe "group members" do
    setup do
      user = user_fixture()
      member_user = user_fixture(%{phone_number: "+27987654321"})
      {:ok, group} = Communities.create_group(Map.put(%{
        name: "Test Group",
        description: "Test",
        is_public: true,
        created_by_id: user.id
      }, :created_by_id, user.id))

      %{group: group, creator: user, member_user: member_user}
    end

    test "join_group/3 adds a user to a group", %{group: group, member_user: user} do
      assert {:ok, %GroupMember{} = member} = Communities.join_group(group.id, user.id)
      assert member.group_id == group.id
      assert member.user_id == user.id
      assert member.role == "member"

      # Verify member count increased
      updated_group = Communities.get_group!(group.id)
      assert updated_group.member_count == 2
    end

    test "join_group/3 with custom role adds user with specified role", %{group: group, member_user: user} do
      assert {:ok, %GroupMember{} = member} = Communities.join_group(group.id, user.id, "moderator")
      assert member.role == "moderator"
    end

    test "join_group/3 prevents duplicate membership", %{group: group, member_user: user} do
      {:ok, _member} = Communities.join_group(group.id, user.id)

      # Try to join again
      assert {:error, %Ecto.Changeset{}} = Communities.join_group(group.id, user.id)
    end

    test "leave_group/2 removes a user from a group", %{group: group, member_user: user} do
      {:ok, _member} = Communities.join_group(group.id, user.id)

      assert {:ok, :ok} = Communities.leave_group(group.id, user.id)

      # Verify member is removed
      assert Communities.get_group_member(group.id, user.id) == nil

      # Verify member count decreased
      updated_group = Communities.get_group!(group.id)
      assert updated_group.member_count == 1
    end

    test "leave_group/2 returns error if user is not a member", %{group: group, member_user: user} do
      assert {:error, :not_a_member} = Communities.leave_group(group.id, user.id)
    end

    test "update_member_role/3 updates a member's role", %{group: group, member_user: user} do
      {:ok, _member} = Communities.join_group(group.id, user.id)

      assert {:ok, updated_member} = Communities.update_member_role(group.id, user.id, "moderator")
      assert updated_member.role == "moderator"
    end

    test "update_member_role/3 returns error for non-existent member", %{group: group, member_user: user} do
      assert {:error, :not_found} = Communities.update_member_role(group.id, user.id, "moderator")
    end

    test "list_group_members/1 returns all members of a group", %{group: group, creator: creator, member_user: user} do
      {:ok, _member} = Communities.join_group(group.id, user.id)

      members = Communities.list_group_members(group.id)

      assert length(members) == 2
      assert Enum.any?(members, fn m -> m.user_id == creator.id end)
      assert Enum.any?(members, fn m -> m.user_id == user.id end)
    end

    test "member?/2 returns true if user is a member", %{group: group, member_user: user} do
      {:ok, _member} = Communities.join_group(group.id, user.id)

      assert Communities.member?(group.id, user.id) == true
    end

    test "member?/2 returns false if user is not a member", %{group: group, member_user: user} do
      assert Communities.member?(group.id, user.id) == false
    end

    test "can_moderate?/2 returns true for admin", %{group: group, creator: creator} do
      assert Communities.can_moderate?(group.id, creator.id) == true
    end

    test "can_moderate?/2 returns true for moderator", %{group: group, member_user: user} do
      {:ok, _member} = Communities.join_group(group.id, user.id, "moderator")

      assert Communities.can_moderate?(group.id, user.id) == true
    end

    test "can_moderate?/2 returns false for regular member", %{group: group, member_user: user} do
      {:ok, _member} = Communities.join_group(group.id, user.id, "member")

      assert Communities.can_moderate?(group.id, user.id) == false
    end

    test "update_notification_preferences/3 updates member notification settings", %{group: group, member_user: user} do
      {:ok, _member} = Communities.join_group(group.id, user.id)

      assert {:ok, updated_member} = Communities.update_notification_preferences(group.id, user.id, false)
      assert updated_member.notifications_enabled == false
    end
  end

  describe "group incidents" do
    setup do
      user = user_fixture()
      {:ok, group} = Communities.create_group(%{
        name: "Test Group",
        description: "Test",
        is_public: true,
        center_latitude: -26.2041,
        center_longitude: 28.0473,
        radius_meters: 5000,
        created_by_id: user.id
      })

      incident = incident_fixture(%{
        user_id: user.id,
        latitude: -26.2041,
        longitude: 28.0473
      })

      %{group: group, user: user, incident: incident}
    end

    test "add_incident_to_group/2 links an incident to a group", %{group: group, incident: incident} do
      assert {:ok, _group_incident} = Communities.add_incident_to_group(group.id, incident.id)

      # Verify incident appears in group feed
      result = Communities.list_group_incidents(group.id)
      assert length(result.incidents) == 1
      assert hd(result.incidents).id == incident.id
    end

    test "add_incident_to_group/2 prevents duplicate links", %{group: group, incident: incident} do
      {:ok, _} = Communities.add_incident_to_group(group.id, incident.id)

      # Try to add again
      assert {:error, %Ecto.Changeset{}} = Communities.add_incident_to_group(group.id, incident.id)
    end

    test "list_group_incidents/2 returns incidents within group radius", %{group: group, user: user, incident: setup_incident} do
      # Create incident within radius
      nearby_incident = incident_fixture(%{
        user_id: user.id,
        latitude: -26.2041,
        longitude: 28.0473
      })

      # Create incident outside radius
      _far_incident = incident_fixture(%{
        user_id: user.id,
        latitude: -26.5041,
        longitude: 28.5473
      })

      result = Communities.list_group_incidents(group.id)

      # Should have 2 incidents within radius (setup_incident + nearby_incident)
      assert length(result.incidents) == 2
      incident_ids = Enum.map(result.incidents, & &1.id)
      assert setup_incident.id in incident_ids
      assert nearby_incident.id in incident_ids
    end

    test "list_group_incidents/2 filters by type", %{group: group, user: user, incident: setup_incident} do
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

      result = Communities.list_group_incidents(group.id, type: "hijacking")

      # Should have 2 hijacking incidents (setup_incident + hijacking)
      assert length(result.incidents) == 2
      assert Enum.all?(result.incidents, fn i -> i.type == "hijacking" end)
    end

    test "list_group_incidents/2 supports pagination", %{group: group, user: user} do
      # Create multiple incidents (plus 1 from setup = 26 total)
      for _ <- 1..25 do
        incident_fixture(%{
          user_id: user.id,
          latitude: -26.2041,
          longitude: 28.0473
        })
      end

      page1 = Communities.list_group_incidents(group.id, page: 1, page_size: 10)
      page2 = Communities.list_group_incidents(group.id, page: 2, page_size: 10)

      assert length(page1.incidents) == 10
      assert length(page2.incidents) == 10
      assert page1.total_count == 26  # 25 + 1 from setup
      assert page1.total_pages == 3
    end

    test "remove_incident_from_group/2 removes incident link", %{group: group, incident: incident} do
      {:ok, _} = Communities.add_incident_to_group(group.id, incident.id)

      assert {1, _} = Communities.remove_incident_from_group(group.id, incident.id)

      # Verify incident no longer explicitly linked (may still appear if within radius)
      # We can't easily test this without mocking the radius check
    end
  end

  describe "group creation with location" do
    test "creates group with valid coordinates" do
      user = user_fixture()

      attrs = %{
        name: "Location Group",
        description: "Test",
        is_public: true,
        center_latitude: -26.2041,
        center_longitude: 28.0473,
        radius_meters: 3000,
        created_by_id: user.id
      }

      assert {:ok, group} = Communities.create_group(attrs)
      assert group.center_latitude == -26.2041
      assert group.center_longitude == 28.0473
      assert group.radius_meters == 3000
    end

    test "creates group without location" do
      user = user_fixture()

      attrs = %{
        name: "No Location Group",
        description: "Test",
        is_public: true,
        created_by_id: user.id
      }

      assert {:ok, group} = Communities.create_group(attrs)
      assert group.center_latitude == nil
      assert group.center_longitude == nil
      assert group.radius_meters == 5000  # Default value
    end
  end

  describe "group visibility" do
    test "public groups are visible to all" do
      user = user_fixture()
      {:ok, public_group} = Communities.create_group(%{
        name: "Public Group",
        description: "Test",
        is_public: true,
        created_by_id: user.id
      })

      public_groups = Communities.list_public_groups()
      assert Enum.any?(public_groups, fn g -> g.id == public_group.id end)
    end

    test "private groups are not in public list" do
      user = user_fixture()
      {:ok, private_group} = Communities.create_group(%{
        name: "Private Group",
        description: "Test",
        is_public: false,
        created_by_id: user.id
      })

      public_groups = Communities.list_public_groups()
      refute Enum.any?(public_groups, fn g -> g.id == private_group.id end)
    end
  end
end
