defmodule HotspotApiWeb.GeofenceChannel do
  use HotspotApiWeb, :channel

  alias HotspotApi.Geofencing
  alias HotspotApi.Accounts
  alias HotspotApi.Notifications

  @impl true
  def join("geofence:user:" <> user_id, _payload, socket) do
    # Verify that the user_id matches the authenticated user
    case socket.assigns[:user_id] do
      ^user_id ->
        socket = assign(socket, :user_id, user_id)
        {:ok, socket}

      _ ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("location:update", %{"latitude" => lat, "longitude" => lng}, socket) do
    user_id = socket.assigns[:user_id]

    # Get user to check premium status
    user = Accounts.get_user!(user_id)

    # Check if user is in any hotspot zones
    zones_at_location = Geofencing.check_location(lat, lng)

    # Get zones user is currently tracked as being in
    current_zones = Geofencing.get_user_current_zones(user_id)
    current_zone_ids = Enum.map(current_zones, & &1.id)

    # Detect zone entries (zones at location that user is not currently in)
    new_zones = Enum.filter(zones_at_location, fn zone ->
      zone.id not in current_zone_ids
    end)

    # Detect zone exits (zones user is in but not at current location)
    exited_zones = Enum.filter(current_zones, fn zone ->
      zone.id not in Enum.map(zones_at_location, & &1.id)
    end)

    # Handle zone entries
    Enum.each(new_zones, fn zone ->
      # Track zone entry
      {:ok, tracking} = Geofencing.track_zone_entry(user_id, zone.id)

      # Send notification if not already sent
      unless tracking.notification_sent do
        send_zone_entry_notification(user, zone)
        Geofencing.mark_notification_sent(tracking)
      end

      # Broadcast zone entry event to client
      push(socket, "zone:entered", format_zone_event(zone, "entered"))
    end)

    # Handle zone exits
    Enum.each(exited_zones, fn zone ->
      # Track zone exit
      Geofencing.track_zone_exit(user_id, zone.id)

      # Broadcast zone exit event to client
      push(socket, "zone:exited", format_zone_event(zone, "exited"))

      # Send exit notification
      send_zone_exit_notification(user, zone)
    end)

    # Check for approaching zones (premium users only)
    if user.is_premium do
      approaching_zones = Geofencing.check_approaching_zones(lat, lng, true)

      # Filter out zones user is already in or has been notified about recently
      new_approaching = Enum.filter(approaching_zones, fn zone ->
        zone.id not in current_zone_ids
      end)

      # Send approaching notifications
      Enum.each(new_approaching, fn zone ->
        push(socket, "zone:approaching", format_zone_event(zone, "approaching"))
        send_zone_approaching_notification(user, zone)
      end)
    end

    {:reply, {:ok, %{zones_entered: length(new_zones), zones_exited: length(exited_zones)}}, socket}
  end

  @impl true
  def handle_in("location:update", _payload, socket) do
    {:reply, {:error, %{reason: "missing latitude or longitude"}}, socket}
  end

  # Format zone data for client
  defp format_zone_event(zone, action) do
    %Geo.Point{coordinates: {lng, lat}} = zone.center_location

    %{
      zone_id: zone.id,
      zone_type: zone.zone_type,
      risk_level: zone.risk_level,
      incident_count: zone.incident_count,
      center: %{
        latitude: lat,
        longitude: lng
      },
      radius_meters: zone.radius_meters,
      action: action,
      message: format_zone_message(zone, action)
    }
  end

  # Format notification message based on action
  defp format_zone_message(zone, "entered") do
    "⚠️ Entering #{String.upcase(zone.risk_level)} RISK zone - #{zone.incident_count} #{zone.zone_type} reported in this area in the past 7 days. Stay alert."
  end

  defp format_zone_message(_zone, "exited") do
    "✓ You have left the hotspot zone. Stay safe."
  end

  defp format_zone_message(zone, "approaching") do
    "⚠️ Approaching #{String.upcase(zone.risk_level)} RISK zone ahead - #{zone.incident_count} #{zone.zone_type} reported"
  end

  # Send FCM notification for zone entry
  defp send_zone_entry_notification(user, zone) do
    # Check if user has hotspot zone alerts enabled
    notification_config = user.notification_config || %{}

    if Map.get(notification_config, "hotspot_zone_alerts", true) do
      message = format_zone_message(zone, "entered")

      Notifications.send_push_notification(user.id, %{
        title: "Hotspot Zone Alert",
        body: message,
        data: %{
          type: "hotspot_zone",
          zone_id: zone.id,
          zone_type: zone.zone_type,
          risk_level: zone.risk_level,
          action: "entered"
        }
      })
    end
  end

  # Send FCM notification for zone exit
  defp send_zone_exit_notification(user, zone) do
    notification_config = user.notification_config || %{}

    if Map.get(notification_config, "hotspot_zone_alerts", true) do
      message = format_zone_message(zone, "exited")

      Notifications.send_push_notification(user.id, %{
        title: "Hotspot Zone Alert",
        body: message,
        data: %{
          type: "hotspot_zone",
          zone_id: zone.id,
          action: "exited"
        }
      })
    end
  end

  # Send FCM notification for approaching zone (premium only)
  defp send_zone_approaching_notification(user, zone) do
    notification_config = user.notification_config || %{}

    if Map.get(notification_config, "hotspot_zone_alerts", true) do
      message = format_zone_message(zone, "approaching")

      Notifications.send_push_notification(user.id, %{
        title: "Hotspot Zone Alert",
        body: message,
        data: %{
          type: "hotspot_zone",
          zone_id: zone.id,
          zone_type: zone.zone_type,
          risk_level: zone.risk_level,
          action: "approaching"
        }
      })
    end
  end

  @doc """
  Broadcast zone creation to all subscribed users.
  This should be called when a new zone is created.
  """
  def broadcast_zone_created(zone) do
    %Geo.Point{coordinates: {lng, lat}} = zone.center_location

    HotspotApiWeb.Endpoint.broadcast(
      "geofence:zones",
      "zone:created",
      %{
        id: zone.id,
        zone_type: zone.zone_type,
        risk_level: zone.risk_level,
        incident_count: zone.incident_count,
        center: %{
          latitude: lat,
          longitude: lng
        },
        radius_meters: zone.radius_meters,
        is_active: zone.is_active
      }
    )

    :ok
  end

  @doc """
  Broadcast zone dissolution to all subscribed users.
  """
  def broadcast_zone_dissolved(zone) do
    HotspotApiWeb.Endpoint.broadcast(
      "geofence:zones",
      "zone:dissolved",
      %{
        id: zone.id,
        zone_type: zone.zone_type
      }
    )

    :ok
  end
end
