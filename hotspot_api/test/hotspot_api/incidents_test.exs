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
  end
end
