defmodule HotspotApi.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  def up do
    # Incidents table indexes for common queries
    create_if_not_exists index(:incidents, [:type, :inserted_at])
    create_if_not_exists index(:incidents, [:user_id, :inserted_at])
    create_if_not_exists index(:incidents, [:is_verified, :inserted_at])
    create_if_not_exists index(:incidents, [:expires_at])

    # Separate indexes for type and location (GIST doesn't support varchar without operator class)
    # The location GIST index already exists from create_incidents migration

    # Incident verifications for counting
    create_if_not_exists index(:incident_verifications, [:incident_id])
    create_if_not_exists index(:incident_verifications, [:user_id, :inserted_at])

    # Hotspot zones for geofencing queries
    create_if_not_exists index(:hotspot_zones, [:is_active, :zone_type])
    create_if_not_exists index(:hotspot_zones, [:risk_level, :is_active])
    create_if_not_exists index(:hotspot_zones, [:center_location], using: "GIST")

    # User zone tracking for entry/exit detection
    create_if_not_exists index(:user_zone_tracking, [:user_id, :exited_at])
    create_if_not_exists index(:user_zone_tracking, [:zone_id, :entered_at])

    # FCM tokens for notification delivery
    create_if_not_exists index(:fcm_tokens, [:user_id])
    create_if_not_exists index(:fcm_tokens, [:platform])

    # Users for authentication and premium checks
    create_if_not_exists index(:users, [:phone_number])
    create_if_not_exists index(:users, [:is_premium, :premium_expires_at])

    # OTP codes for verification
    create_if_not_exists index(:otp_codes, [:phone_number, :expires_at])
    create_if_not_exists index(:otp_codes, [:verified, :expires_at])

    # Subscriptions for payment tracking (indexes already created in create_subscriptions migration)

    # Security tables for intrusion detection (indexes already created in create_security_tables migration)

    # Moderation tables
    create_if_not_exists index(:flagged_content, [:status, :inserted_at])
    create_if_not_exists index(:flagged_content, [:incident_id])
    create_if_not_exists index(:image_hashes, [:hash])
  end

  def down do
    drop_if_exists index(:incidents, [:type, :inserted_at])
    drop_if_exists index(:incidents, [:user_id, :inserted_at])
    drop_if_exists index(:incidents, [:is_verified, :inserted_at])
    drop_if_exists index(:incidents, [:expires_at])
    # No composite index to drop

    drop_if_exists index(:incident_verifications, [:incident_id])
    drop_if_exists index(:incident_verifications, [:user_id, :inserted_at])

    drop_if_exists index(:hotspot_zones, [:is_active, :zone_type])
    drop_if_exists index(:hotspot_zones, [:risk_level, :is_active])
    drop_if_exists index(:hotspot_zones, [:center_location])

    drop_if_exists index(:user_zone_tracking, [:user_id, :exited_at])
    drop_if_exists index(:user_zone_tracking, [:zone_id, :entered_at])

    drop_if_exists index(:fcm_tokens, [:user_id])
    drop_if_exists index(:fcm_tokens, [:platform])

    drop_if_exists index(:users, [:phone_number])
    drop_if_exists index(:users, [:is_premium, :premium_expires_at])

    drop_if_exists index(:otp_codes, [:phone_number, :expires_at])
    drop_if_exists index(:otp_codes, [:verified, :expires_at])

    # Subscription indexes managed in create_subscriptions migration

    # Security table indexes managed in create_security_tables migration

    drop_if_exists index(:flagged_content, [:status, :inserted_at])
    drop_if_exists index(:flagged_content, [:incident_id])
    drop_if_exists index(:image_hashes, [:hash])
  end
end
