defmodule HotspotApi.AdminTest do
  use HotspotApi.DataCase

  import HotspotApi.AccountsFixtures
  import HotspotApi.IncidentsFixtures
  import HotspotApi.AdminFixtures

  alias HotspotApi.Admin
  alias HotspotApi.Admin.AdminUser

  describe "admin users" do
    @valid_attrs %{
      email: "admin@example.com",
      password: "SecurePassword123!",
      name: "Test Admin",
      role: "moderator"
    }
    @invalid_attrs %{email: nil, password: nil}

    test "get_admin_by_email/1 returns admin with given email" do
      admin = admin_user_fixture()
      assert Admin.get_admin_by_email(admin.email).id == admin.id
    end

    test "get_admin_by_email/1 returns nil for non-existent email" do
      assert Admin.get_admin_by_email("nonexistent@example.com") == nil
    end

    test "get_admin!/1 returns the admin with given id" do
      admin = admin_user_fixture()
      assert Admin.get_admin!(admin.id).id == admin.id
    end

    test "create_admin/1 with valid data creates an admin" do
      assert {:ok, %AdminUser{} = admin} = Admin.create_admin(@valid_attrs)
      assert admin.email == "admin@example.com"
      assert admin.name == "Test Admin"
      assert admin.role == "moderator"
      assert admin.is_active == true
      assert Argon2.verify_pass("SecurePassword123!", admin.password_hash)
    end

    test "create_admin/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Admin.create_admin(@invalid_attrs)
    end

    test "create_admin/1 with duplicate email returns error" do
      admin = admin_user_fixture()
      assert {:error, %Ecto.Changeset{}} = Admin.create_admin(%{@valid_attrs | email: admin.email})
    end

    test "authenticate_admin/2 with valid credentials returns admin" do
      admin = admin_user_fixture(%{password: "SecurePassword123!"})
      assert {:ok, authenticated_admin} = Admin.authenticate_admin(admin.email, "SecurePassword123!")
      assert authenticated_admin.id == admin.id
    end

    test "authenticate_admin/2 with invalid password returns error" do
      admin = admin_user_fixture(%{password: "SecurePassword123!"})
      assert {:error, :invalid_credentials} = Admin.authenticate_admin(admin.email, "WrongPassword")
    end

    test "authenticate_admin/2 with non-existent email returns error" do
      assert {:error, :invalid_credentials} = Admin.authenticate_admin("nonexistent@example.com", "password")
    end

    test "authenticate_admin/2 with inactive admin returns error" do
      admin = admin_user_fixture(%{password: "SecurePassword123!", is_active: false})
      assert {:error, :invalid_credentials} = Admin.authenticate_admin(admin.email, "SecurePassword123!")
    end

    test "update_admin/2 with valid data updates the admin" do
      admin = admin_user_fixture()
      update_attrs = %{name: "Updated Name", role: "analyst"}

      assert {:ok, %AdminUser{} = updated_admin} = Admin.update_admin(admin, update_attrs)
      assert updated_admin.name == "Updated Name"
      assert updated_admin.role == "analyst"
    end

    test "update_last_login/1 updates the last_login_at timestamp" do
      admin = admin_user_fixture()
      assert admin.last_login_at == nil

      assert {:ok, updated_admin} = Admin.update_last_login(admin)
      assert updated_admin.last_login_at != nil
    end

    test "list_admins/0 returns all admins" do
      admin1 = admin_user_fixture()
      admin2 = admin_user_fixture(%{email: "admin2@example.com"})

      admins = Admin.list_admins()
      assert length(admins) == 2
      assert Enum.any?(admins, fn a -> a.id == admin1.id end)
      assert Enum.any?(admins, fn a -> a.id == admin2.id end)
    end
  end

  describe "dashboard statistics" do
    test "get_dashboard_stats/0 returns correct statistics" do
      user = user_fixture()
      _incident1 = incident_fixture(%{user_id: user.id, is_verified: true})
      _incident2 = incident_fixture(%{user_id: user.id, is_verified: false})

      stats = Admin.get_dashboard_stats()

      assert stats.total_incidents == 2
      assert stats.active_users >= 1
      assert stats.verification_rate == 50.0
      assert is_number(stats.hotspot_zones)
      assert is_number(stats.revenue_this_month)
    end

    test "get_dashboard_stats/0 handles zero incidents" do
      stats = Admin.get_dashboard_stats()

      assert stats.total_incidents == 0
      assert stats.verification_rate == 0.0
    end
  end

  describe "recent activity" do
    test "get_recent_activity/1 returns recent incidents" do
      user = user_fixture()
      incident = incident_fixture(%{user_id: user.id})

      activities = Admin.get_recent_activity(10)

      assert length(activities) == 1
      activity = hd(activities)
      assert activity.type == "incident_created"
      assert activity.incident_type == incident.type
      assert activity.metadata.incident_id == incident.id
    end

    test "get_recent_activity/1 respects limit parameter" do
      user = user_fixture()

      for _ <- 1..25 do
        incident_fixture(%{user_id: user.id})
      end

      activities = Admin.get_recent_activity(10)
      assert length(activities) == 10
    end
  end

  describe "incident pagination and filtering" do
    setup do
      user = user_fixture()

      incident1 = incident_fixture(%{
        user_id: user.id,
        type: "hijacking",
        description: "Test hijacking",
        is_verified: true
      })

      incident2 = incident_fixture(%{
        user_id: user.id,
        type: "mugging",
        description: "Test mugging",
        is_verified: false
      })

      %{user: user, incident1: incident1, incident2: incident2}
    end

    test "list_incidents_paginated/5 returns paginated incidents", %{incident1: i1, incident2: i2} do
      filters = %{type: nil, status: nil, is_verified: nil, search: nil, start_date: nil, end_date: nil}

      result = Admin.list_incidents_paginated(1, 10, filters, "inserted_at", "desc")

      assert result.page == 1
      assert result.page_size == 10
      assert result.total_count == 2
      assert length(result.incidents) == 2
      assert Enum.any?(result.incidents, fn i -> i.id == i1.id end)
      assert Enum.any?(result.incidents, fn i -> i.id == i2.id end)
    end

    test "list_incidents_paginated/5 filters by type", %{incident1: i1} do
      filters = %{type: "hijacking", status: nil, is_verified: nil, search: nil, start_date: nil, end_date: nil}

      result = Admin.list_incidents_paginated(1, 10, filters, "inserted_at", "desc")

      assert result.total_count == 1
      assert hd(result.incidents).id == i1.id
    end

    test "list_incidents_paginated/5 filters by verified status", %{incident1: i1} do
      filters = %{type: nil, status: nil, is_verified: "true", search: nil, start_date: nil, end_date: nil}

      result = Admin.list_incidents_paginated(1, 10, filters, "inserted_at", "desc")

      assert result.total_count == 1
      assert hd(result.incidents).id == i1.id
      assert hd(result.incidents).is_verified == true
    end

    test "list_incidents_paginated/5 filters by search term", %{incident1: i1} do
      filters = %{type: nil, status: nil, is_verified: nil, search: "hijacking", start_date: nil, end_date: nil}

      result = Admin.list_incidents_paginated(1, 10, filters, "inserted_at", "desc")

      assert result.total_count == 1
      assert hd(result.incidents).id == i1.id
    end

    test "list_incidents_paginated/5 sorts by type ascending" do
      filters = %{type: nil, status: nil, is_verified: nil, search: nil, start_date: nil, end_date: nil}

      result = Admin.list_incidents_paginated(1, 10, filters, "type", "asc")

      assert length(result.incidents) == 2
      assert hd(result.incidents).type == "hijacking"
    end

    test "list_incidents_paginated/5 handles pagination correctly" do
      user = user_fixture()

      for _ <- 1..15 do
        incident_fixture(%{user_id: user.id})
      end

      filters = %{type: nil, status: nil, is_verified: nil, search: nil, start_date: nil, end_date: nil}

      page1 = Admin.list_incidents_paginated(1, 10, filters, "inserted_at", "desc")
      page2 = Admin.list_incidents_paginated(2, 10, filters, "inserted_at", "desc")

      assert page1.total_count == 17  # 15 + 2 from setup
      assert length(page1.incidents) == 10
      assert length(page2.incidents) == 7
      assert page1.total_pages == 2
    end
  end

  describe "incident moderation" do
    setup do
      user = user_fixture()
      admin = admin_user_fixture()
      incident = incident_fixture(%{user_id: user.id, is_verified: false})

      %{user: user, admin: admin, incident: incident}
    end

    test "moderate_incident/4 approves incident", %{admin: admin, incident: incident} do
      assert {:ok, updated_incident} = Admin.moderate_incident(incident.id, "approve", admin.id)
      assert updated_incident.is_verified == true
    end

    @tag :skip
    test "moderate_incident/4 flags incident", %{admin: admin, incident: incident} do
      # Skipped: Moderation.create_flagged_content/1 not implemented yet
      assert {:ok, _} = Admin.moderate_incident(incident.id, "flag", admin.id, "Inappropriate content")

      # Verify flagged content was created
      flagged = HotspotApi.Repo.get_by(HotspotApi.Moderation.FlaggedContent, incident_id: incident.id)
      assert flagged != nil
      assert flagged.flag_reason == "Inappropriate content"
    end

    test "moderate_incident/4 deletes incident", %{admin: admin, incident: incident} do
      assert {:ok, _} = Admin.moderate_incident(incident.id, "delete", admin.id)
      assert_raise Ecto.NoResultsError, fn -> HotspotApi.Incidents.get_incident!(incident.id) end
    end

    test "moderate_incident/4 returns error for invalid action", %{admin: admin, incident: incident} do
      assert {:error, :invalid_action} = Admin.moderate_incident(incident.id, "invalid", admin.id)
    end
  end

  describe "bulk moderation" do
    setup do
      user = user_fixture()
      admin = admin_user_fixture()

      incident1 = incident_fixture(%{user_id: user.id, is_verified: false})
      incident2 = incident_fixture(%{user_id: user.id, is_verified: false})
      incident3 = incident_fixture(%{user_id: user.id, is_verified: false})

      %{user: user, admin: admin, incidents: [incident1, incident2, incident3]}
    end

    test "bulk_moderate_incidents/4 approves multiple incidents", %{admin: admin, incidents: incidents} do
      incident_ids = Enum.map(incidents, & &1.id)

      assert {:ok, count} = Admin.bulk_moderate_incidents(incident_ids, "approve", admin.id)
      assert count == 3

      # Verify all incidents are now verified
      for incident_id <- incident_ids do
        incident = HotspotApi.Incidents.get_incident!(incident_id)
        assert incident.is_verified == true
      end
    end

    @tag :skip
    test "bulk_moderate_incidents/4 flags multiple incidents", %{admin: admin, incidents: incidents} do
      # Skipped: Moderation.create_flagged_content/1 not implemented yet
      incident_ids = Enum.map(incidents, & &1.id)

      assert {:ok, count} = Admin.bulk_moderate_incidents(incident_ids, "flag", admin.id, "Bulk flag")
      assert count == 3

      # Verify flagged content was created for all
      for incident_id <- incident_ids do
        flagged = HotspotApi.Repo.get_by(HotspotApi.Moderation.FlaggedContent, incident_id: incident_id)
        assert flagged != nil
      end
    end

    test "bulk_moderate_incidents/4 deletes multiple incidents", %{admin: admin, incidents: incidents} do
      incident_ids = Enum.map(incidents, & &1.id)

      assert {:ok, count} = Admin.bulk_moderate_incidents(incident_ids, "delete", admin.id)
      assert count == 3

      # Verify all incidents are deleted
      for incident_id <- incident_ids do
        assert_raise Ecto.NoResultsError, fn -> HotspotApi.Incidents.get_incident!(incident_id) end
      end
    end
  end

  describe "audit logging" do
    test "log_audit/6 creates audit log entry" do
      admin = admin_user_fixture()
      resource_id = Ecto.UUID.generate()

      assert {:ok, log} = Admin.log_audit(
        admin.id,
        "delete_incident",
        "incident",
        resource_id,
        %{reason: "test"},
        "127.0.0.1"
      )

      assert log.admin_user_id == admin.id
      assert log.action == "delete_incident"
      assert log.resource_type == "incident"
      assert log.resource_id == resource_id
      assert log.details == %{reason: "test"}
      assert log.ip_address == "127.0.0.1"
    end
  end

  describe "user management" do
    setup do
      admin = admin_user_fixture()
      user1 = user_fixture(%{is_premium: true})
      user2 = user_fixture(%{phone_number: "+27987654321", is_premium: false})

      %{admin: admin, user1: user1, user2: user2}
    end

    test "list_users_paginated/5 returns paginated users", %{user1: u1, user2: u2} do
      filters = %{is_premium: nil, search: nil, start_date: nil, end_date: nil}

      result = Admin.list_users_paginated(1, 10, filters, "inserted_at", "desc")

      assert result.page == 1
      assert result.total_count == 2
      assert length(result.users) == 2
      assert Enum.any?(result.users, fn u -> u.id == u1.id end)
      assert Enum.any?(result.users, fn u -> u.id == u2.id end)
    end

    test "list_users_paginated/5 filters by premium status", %{user1: u1} do
      filters = %{is_premium: "true", search: nil, start_date: nil, end_date: nil}

      result = Admin.list_users_paginated(1, 10, filters, "inserted_at", "desc")

      assert result.total_count == 1
      assert hd(result.users).id == u1.id
    end

    test "list_users_paginated/5 filters by search term", %{user1: u1} do
      filters = %{is_premium: nil, search: u1.phone_number, start_date: nil, end_date: nil}

      result = Admin.list_users_paginated(1, 10, filters, "inserted_at", "desc")

      assert result.total_count == 1
      assert hd(result.users).id == u1.id
    end

    test "get_user_with_details!/1 returns user with details", %{user1: user} do
      detailed_user = Admin.get_user_with_details!(user.id)

      assert detailed_user.id == user.id
      assert detailed_user.phone_number == user.phone_number
    end

    test "suspend_user/3 suspends a user account", %{admin: admin, user1: user} do
      assert {:ok, suspended_user} = Admin.suspend_user(user.id, admin.id, "Violation of terms")

      assert suspended_user.notification_config["suspended"] == true
      assert suspended_user.notification_config["suspended_by"] == admin.id
      assert suspended_user.notification_config["suspension_reason"] == "Violation of terms"
    end

    test "ban_user/3 bans a user account", %{admin: admin, user1: user} do
      assert {:ok, banned_user} = Admin.ban_user(user.id, admin.id, "Repeated violations")

      assert banned_user.notification_config["banned"] == true
      assert banned_user.notification_config["banned_by"] == admin.id
      assert banned_user.notification_config["ban_reason"] == "Repeated violations"
    end

    test "update_user_premium/4 grants premium status", %{admin: admin, user2: user} do
      expires_at = DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)

      assert {:ok, premium_user} = Admin.update_user_premium(user.id, true, admin.id, expires_at)

      assert premium_user.is_premium == true
      assert premium_user.premium_expires_at == expires_at
    end

    test "update_user_premium/4 revokes premium status", %{admin: admin, user1: user} do
      assert {:ok, free_user} = Admin.update_user_premium(user.id, false, admin.id)

      assert free_user.is_premium == false
      # Alert radius should be limited to 2km for free users
      assert free_user.alert_radius <= 2000
    end

    test "get_user_activity/2 returns user activity log", %{user1: user, user2: other_user} do
      # Create incident by user
      incident = incident_fixture(%{user_id: user.id})

      # Create another incident that user can verify
      other_incident = incident_fixture(%{user_id: other_user.id})
      {:ok, _} = HotspotApi.Incidents.verify_incident(other_incident.id, user.id)

      activities = Admin.get_user_activity(user.id, 50)

      assert length(activities) >= 2
      assert Enum.any?(activities, fn a -> a.type == "incident_reported" end)
      assert Enum.any?(activities, fn a -> a.type == "incident_verified" end)
    end
  end

  describe "analytics" do
    setup do
      user = user_fixture()

      # Create incidents with different types and times
      for type <- ["hijacking", "mugging", "accident"] do
        incident_fixture(%{user_id: user.id, type: type})
      end

      %{user: user}
    end

    test "get_analytics_trends/2 returns incident trends" do
      start_date = DateTime.utc_now() |> DateTime.add(-7, :day)
      end_date = DateTime.utc_now()

      trends = Admin.get_analytics_trends(start_date, end_date)

      assert is_list(trends)
      # Should have data for today at least
      assert length(trends) >= 1
    end

    test "get_analytics_heatmap/2 returns heatmap data" do
      start_date = DateTime.utc_now() |> DateTime.add(-7, :day)
      end_date = DateTime.utc_now()

      heatmap = Admin.get_analytics_heatmap(start_date, end_date)

      assert is_list(heatmap)
    end

    test "get_analytics_peak_hours/2 returns peak hours analysis" do
      start_date = DateTime.utc_now() |> DateTime.add(-7, :day)
      end_date = DateTime.utc_now()

      peak_hours = Admin.get_analytics_peak_hours(start_date, end_date)

      assert is_list(peak_hours)
    end

    test "get_analytics_user_metrics/2 returns user engagement metrics" do
      start_date = DateTime.utc_now() |> DateTime.add(-7, :day)
      end_date = DateTime.utc_now()

      metrics = Admin.get_analytics_user_metrics(start_date, end_date)

      assert is_map(metrics)
      assert Map.has_key?(metrics, :daily_active_users)
      assert Map.has_key?(metrics, :total_users)
      assert Map.has_key?(metrics, :verification_participation_rate)
      assert Map.has_key?(metrics, :retention_rate)
    end

    test "get_analytics_revenue/2 returns revenue metrics" do
      start_date = DateTime.utc_now() |> DateTime.add(-30, :day)
      end_date = DateTime.utc_now()

      revenue = Admin.get_analytics_revenue(start_date, end_date)

      assert is_map(revenue)
      assert Map.has_key?(revenue, :total_revenue)
      assert Map.has_key?(revenue, :monthly_subscriptions)
      assert Map.has_key?(revenue, :annual_subscriptions)
    end

    test "export_analytics_csv/3 exports trends data as CSV" do
      start_date = DateTime.utc_now() |> DateTime.add(-7, :day)
      end_date = DateTime.utc_now()

      csv = Admin.export_analytics_csv("trends", start_date, end_date)

      assert is_binary(csv)
      assert csv =~ "Date,Hijacking,Mugging,Accident,Total"
    end

    test "export_analytics_csv/3 exports peak hours data as CSV" do
      start_date = DateTime.utc_now() |> DateTime.add(-7, :day)
      end_date = DateTime.utc_now()

      csv = Admin.export_analytics_csv("peak_hours", start_date, end_date)

      assert is_binary(csv)
      assert csv =~ "Hour,Hijacking,Mugging,Accident,Total"
    end

    test "export_analytics_csv/3 exports heatmap data as CSV" do
      start_date = DateTime.utc_now() |> DateTime.add(-7, :day)
      end_date = DateTime.utc_now()

      csv = Admin.export_analytics_csv("heatmap", start_date, end_date)

      assert is_binary(csv)
      assert csv =~ "Latitude,Longitude,Incident Count,Dominant Type"
    end
  end
end
