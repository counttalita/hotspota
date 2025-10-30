defmodule HotspotApi.IncidentsTest do
  use HotspotApi.DataCase

  alias HotspotApi.Incidents

  describe "incidents" do
    alias HotspotApi.Incidents.Incident

    import HotspotApi.IncidentsFixtures
    import HotspotApi.AccountsFixtures

    @invalid_attrs %{type: nil, latitude: nil, longitude: nil}

    test "list_incidents/0 returns all non-expired incidents" do
      incident = incident_fixture()
      assert length(Incidents.list_incidents()) == 1
      assert hd(Incidents.list_incidents()).id == incident.id
    end

    test "get_incident!/1 returns the incident with given id" do
      incident = incident_fixture()
      fetched = Incidents.get_incident!(incident.id)
      assert fetched.id == incident.id
    end

    test "create_incident/1 with valid data creates an incident" do
      user = user_fixture()

      valid_attrs = %{
        type: "hijacking",
        description: "Test incident",
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id
      }

      assert {:ok, %Incident{} = incident} = Incidents.create_incident(valid_attrs)
      assert incident.type == "hijacking"
      assert incident.description == "Test incident"
      assert incident.verification_count == 0
      assert incident.is_verified == false
      assert incident.location != nil
    end

    test "create_incident/1 validates incident type" do
      user = user_fixture()

      invalid_attrs = %{
        type: "invalid_type",
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id
      }

      assert {:error, %Ecto.Changeset{}} = Incidents.create_incident(invalid_attrs)
    end

    test "create_incident/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Incidents.create_incident(@invalid_attrs)
    end

    test "list_nearby/3 returns incidents within radius" do
      user = user_fixture()

      # Create incident at specific location
      {:ok, _incident1} = Incidents.create_incident(%{
        type: "mugging",
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id
      })

      # Create incident far away (should not be returned)
      {:ok, _incident2} = Incidents.create_incident(%{
        type: "accident",
        latitude: -26.3041,
        longitude: 28.1473,
        user_id: user.id
      })

      # Search near first incident
      nearby = Incidents.list_nearby(-26.2041, 28.0473, 5000)

      assert length(nearby) == 1
      assert hd(nearby).type == "mugging"
    end

    test "list_nearby/3 includes distance in results" do
      user = user_fixture()

      {:ok, _incident} = Incidents.create_incident(%{
        type: "hijacking",
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id
      })

      nearby = Incidents.list_nearby(-26.2041, 28.0473, 5000)

      assert length(nearby) == 1
      incident = hd(nearby)
      assert Map.has_key?(incident, :distance)
      assert incident.distance >= 0
    end

    test "delete_incident/1 deletes the incident" do
      incident = incident_fixture()
      assert {:ok, %Incident{}} = Incidents.delete_incident(incident)
      assert_raise Ecto.NoResultsError, fn -> Incidents.get_incident!(incident.id) end
    end

    test "change_incident/1 returns an incident changeset" do
      incident = incident_fixture()
      assert %Ecto.Changeset{} = Incidents.change_incident(incident)
    end

    test "list_nearby_paginated/4 returns paginated incidents" do
      user = user_fixture()

      # Create 25 incidents at the same location
      for _i <- 1..25 do
        Incidents.create_incident(%{
          type: "mugging",
          latitude: -26.2041,
          longitude: 28.0473,
          user_id: user.id
        })
      end

      # Get first page
      result = Incidents.list_nearby_paginated(-26.2041, 28.0473, 5000, page: 1, page_size: 20)

      assert length(result.incidents) == 20
      assert result.total_count == 25
      assert result.page == 1
      assert result.page_size == 20
      assert result.total_pages == 2
    end

    test "list_nearby_paginated/4 filters by incident type" do
      user = user_fixture()

      # Create different types of incidents
      Incidents.create_incident(%{type: "hijacking", latitude: -26.2041, longitude: 28.0473, user_id: user.id})
      Incidents.create_incident(%{type: "mugging", latitude: -26.2041, longitude: 28.0473, user_id: user.id})
      Incidents.create_incident(%{type: "accident", latitude: -26.2041, longitude: 28.0473, user_id: user.id})

      # Filter by hijacking
      result = Incidents.list_nearby_paginated(-26.2041, 28.0473, 5000, type: "hijacking")

      assert length(result.incidents) == 1
      assert hd(result.incidents).type == "hijacking"
    end

    test "list_nearby_paginated/4 filters by time range" do
      user = user_fixture()

      # Create an old incident (simulate by creating and updating)
      {:ok, old_incident} = Incidents.create_incident(%{
        type: "mugging",
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id
      })

      # Update the inserted_at to be 2 days ago
      two_days_ago = DateTime.add(DateTime.utc_now(), -2, :day)
      Repo.update_all(
        from(i in Incident, where: i.id == ^old_incident.id),
        set: [inserted_at: two_days_ago]
      )

      # Create a recent incident
      Incidents.create_incident(%{
        type: "hijacking",
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id
      })

      # Filter by last 24 hours
      result = Incidents.list_nearby_paginated(-26.2041, 28.0473, 5000, time_range: "24h")

      assert length(result.incidents) == 1
      assert hd(result.incidents).type == "hijacking"
    end

    test "list_nearby_paginated/4 includes distance in results" do
      user = user_fixture()

      Incidents.create_incident(%{
        type: "accident",
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id
      })

      result = Incidents.list_nearby_paginated(-26.2041, 28.0473, 5000)

      assert length(result.incidents) == 1
      incident = hd(result.incidents)
      assert Map.has_key?(incident, :distance)
      assert incident.distance >= 0
    end
  end

  describe "incident verification" do
    alias HotspotApi.Incidents.IncidentVerification

    import HotspotApi.IncidentsFixtures
    import HotspotApi.AccountsFixtures

    test "verify_incident/2 creates a verification and increments count" do
      user1 = user_fixture()
      user2 = user_fixture()

      incident = incident_fixture(user: user1)

      assert {:ok, %IncidentVerification{}} = Incidents.verify_incident(incident.id, user2.id)

      # Check that verification count increased
      updated_incident = Incidents.get_incident!(incident.id)
      assert updated_incident.verification_count == 1
      assert updated_incident.is_verified == false
    end

    test "verify_incident/2 prevents duplicate verifications" do
      user1 = user_fixture()
      user2 = user_fixture()

      incident = incident_fixture(user: user1)

      # First verification should succeed
      assert {:ok, _} = Incidents.verify_incident(incident.id, user2.id)

      # Second verification by same user should fail
      assert {:error, %Ecto.Changeset{} = changeset} = Incidents.verify_incident(incident.id, user2.id)
      assert changeset.errors[:incident_id] != nil || changeset.errors[:user_id] != nil
    end

    test "verify_incident/2 prevents self-verification" do
      user = user_fixture()
      incident = incident_fixture(user: user)

      # User trying to verify their own incident should fail
      assert {:error, %Ecto.Changeset{} = changeset} = Incidents.verify_incident(incident.id, user.id)
      assert {"You cannot verify your own incident", _} = changeset.errors[:user_id]
    end

    test "verify_incident/2 auto-verifies incident with 3+ upvotes within 2 hours" do
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()
      user4 = user_fixture()

      incident = incident_fixture(user: user1)

      # Add 3 verifications
      assert {:ok, _} = Incidents.verify_incident(incident.id, user2.id)
      assert {:ok, _} = Incidents.verify_incident(incident.id, user3.id)
      assert {:ok, _} = Incidents.verify_incident(incident.id, user4.id)

      # Check that incident is now verified
      updated_incident = Incidents.get_incident!(incident.id)
      assert updated_incident.verification_count == 3
      assert updated_incident.is_verified == true
    end

    test "verify_incident/2 does not auto-verify old incidents" do
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()
      user4 = user_fixture()

      # Create incident and make it old (3 hours ago)
      incident = incident_fixture(user: user1)
      three_hours_ago = DateTime.add(DateTime.utc_now(), -3, :hour)

      Repo.update_all(
        from(i in HotspotApi.Incidents.Incident, where: i.id == ^incident.id),
        set: [inserted_at: three_hours_ago]
      )

      # Add 3 verifications
      assert {:ok, _} = Incidents.verify_incident(incident.id, user2.id)
      assert {:ok, _} = Incidents.verify_incident(incident.id, user3.id)
      assert {:ok, _} = Incidents.verify_incident(incident.id, user4.id)

      # Check that incident is NOT auto-verified (too old)
      updated_incident = Incidents.get_incident!(incident.id)
      assert updated_incident.verification_count == 3
      assert updated_incident.is_verified == false
    end

    test "get_incident_verifications/1 returns all verifications for an incident" do
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      incident = incident_fixture(user: user1)

      # Add verifications
      {:ok, _} = Incidents.verify_incident(incident.id, user2.id)
      {:ok, _} = Incidents.verify_incident(incident.id, user3.id)

      verifications = Incidents.get_incident_verifications(incident.id)
      assert length(verifications) == 2
    end

    test "user_verified_incident?/2 returns true if user verified incident" do
      user1 = user_fixture()
      user2 = user_fixture()

      incident = incident_fixture(user: user1)

      assert Incidents.user_verified_incident?(incident.id, user2.id) == false

      {:ok, _} = Incidents.verify_incident(incident.id, user2.id)

      assert Incidents.user_verified_incident?(incident.id, user2.id) == true
    end

    test "delete_expired_incidents/0 deletes incidents with zero verifications past expiry" do
      user = user_fixture()

      # Create expired incident with zero verifications
      {:ok, expired_incident} = Incidents.create_incident(%{
        type: "mugging",
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id,
        expires_at: DateTime.add(DateTime.utc_now(), -1, :hour)
      })

      # Create expired incident with verifications (should not be deleted)
      {:ok, verified_incident} = Incidents.create_incident(%{
        type: "hijacking",
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id,
        expires_at: DateTime.add(DateTime.utc_now(), -1, :hour)
      })

      user2 = user_fixture()
      {:ok, _} = Incidents.verify_incident(verified_incident.id, user2.id)

      # Create non-expired incident (should not be deleted)
      {:ok, active_incident} = Incidents.create_incident(%{
        type: "accident",
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id
      })

      # Delete expired incidents
      {deleted_count, _} = Incidents.delete_expired_incidents()

      assert deleted_count == 1

      # Verify correct incident was deleted
      assert_raise Ecto.NoResultsError, fn -> Incidents.get_incident!(expired_incident.id) end
      assert Incidents.get_incident!(verified_incident.id) != nil
      assert Incidents.get_incident!(active_incident.id) != nil
    end
  end
end
