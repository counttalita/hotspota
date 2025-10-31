defmodule HotspotApi.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
  alias HotspotApi.Repo
  alias HotspotApi.Notifications.FcmToken
  alias HotspotApi.Accounts.User
  alias HotspotApi.Incidents.Incident

  @doc """
  Registers or updates an FCM token for a user.
  """
  def register_token(user_id, token, platform) do
    attrs = %{
      user_id: user_id,
      token: token,
      platform: platform
    }

    case Repo.get_by(FcmToken, user_id: user_id, token: token) do
      nil ->
        %FcmToken{}
        |> FcmToken.changeset(attrs)
        |> Repo.insert()

      existing_token ->
        existing_token
        |> FcmToken.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Gets all FCM tokens for a user.
  """
  def get_user_tokens(user_id) do
    FcmToken
    |> where([t], t.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Deletes an FCM token.
  """
  def delete_token(user_id, token) do
    case Repo.get_by(FcmToken, user_id: user_id, token: token) do
      nil -> {:error, :not_found}
      fcm_token -> Repo.delete(fcm_token)
    end
  end

  @doc """
  Sends incident alert to nearby users.
  Queries users within alert radius using PostGIS ST_DWithin.
  """
  def send_incident_alert(incident_id, incident_location) do
    incident = Repo.get!(Incident, incident_id) |> Repo.preload(:user)

    # Get coordinates from the incident location
    %Geo.Point{coordinates: {lng, lat}} = incident_location

    # Query users within their alert radius
    nearby_users_query = """
    SELECT DISTINCT u.id, u.alert_radius, u.notification_config
    FROM users u
    WHERE ST_DWithin(
      ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
      ST_SetSRID(ST_MakePoint(0, 0), 4326)::geography,
      u.alert_radius
    )
    AND u.id != $3
    """

    # Execute raw SQL query to find nearby users
    result = Ecto.Adapters.SQL.query!(
      Repo,
      nearby_users_query,
      [lng, lat, incident.user_id]
    )

    # Get user IDs from result
    user_ids = Enum.map(result.rows, fn [id, _radius, _config] -> id end)

    if length(user_ids) > 0 do
      # Get FCM tokens for nearby users
      tokens_query =
        from t in FcmToken,
          join: u in User,
          on: t.user_id == u.id,
          where: t.user_id in ^user_ids,
          select: {t.token, t.platform, u.notification_config}

      tokens = Repo.all(tokens_query)

      # Filter tokens based on user notification preferences
      filtered_tokens =
        Enum.filter(tokens, fn {_token, _platform, config} ->
          should_send_notification?(config, incident.type)
        end)

      # Calculate distance for notification message
      # For now, we'll use a placeholder distance
      distance = "nearby"

      # Send notifications asynchronously
      Task.start(fn ->
        Enum.each(filtered_tokens, fn {token, platform, _config} ->
          send_push_notification(token, platform, incident, distance)
        end)
      end)

      {:ok, length(filtered_tokens)}
    else
      {:ok, 0}
    end
  end

  @doc """
  Sends a push notification to a user.
  This is a public wrapper for sending custom notifications (e.g., zone alerts).
  """
  def send_push_notification(user_id, %{title: title, body: body, data: data}) do
    # Get user's FCM tokens
    tokens = get_user_tokens(user_id)

    if length(tokens) > 0 do
      # Send to all user's devices
      Task.start(fn ->
        Enum.each(tokens, fn fcm_token ->
          send_fcm_or_apns(fcm_token.token, fcm_token.platform, title, body, data)
        end)
      end)

      {:ok, length(tokens)}
    else
      {:ok, 0}
    end
  end

  # Send notification to FCM or APNS based on platform
  defp send_fcm_or_apns(token, "ios", title, body, data) do
    send_apns_notification(token, title, body, data)
  end

  defp send_fcm_or_apns(token, "android", title, body, data) do
    send_fcm_notification(token, title, body, data)
  end

  defp send_fcm_or_apns(_token, _platform, _title, _body, _data) do
    {:error, :invalid_platform}
  end

  # Check if notification should be sent based on user preferences
  defp should_send_notification?(config, incident_type) do
    # Default to true if no config
    if is_nil(config) or config == %{} do
      true
    else
      # Check if notifications are enabled for this incident type
      case Map.get(config, "enabled_types", %{}) do
        types when is_map(types) ->
          Map.get(types, incident_type, true)

        _ ->
          true
      end
    end
  end

  # Send push notification via FCM
  defp send_push_notification(token, platform, incident, distance) do
    notification_title = "⚠️ #{format_incident_type(incident.type)} Alert"

    notification_body =
      "A #{incident.type} was reported #{distance}. Stay alert and be cautious."

    # Calculate time ago
    time_ago = format_time_ago(incident.inserted_at)

    notification_data = %{
      "incident_id" => incident.id,
      "incident_type" => incident.type,
      "distance" => distance,
      "time" => time_ago,
      "latitude" => get_latitude(incident.location),
      "longitude" => get_longitude(incident.location)
    }

    case platform do
      "ios" ->
        send_apns_notification(token, notification_title, notification_body, notification_data)

      "android" ->
        send_fcm_notification(token, notification_title, notification_body, notification_data)

      _ ->
        {:error, :invalid_platform}
    end
  end

  # Send FCM notification for Android
  defp send_fcm_notification(token, title, body, data) do
    fcm_key = Application.get_env(:hotspot_api, :fcm_server_key)

    if is_nil(fcm_key) do
      {:error, :fcm_key_not_configured}
    else
      notification = %{
        "to" => token,
        "notification" => %{
          "title" => title,
          "body" => body,
          "sound" => "default",
          "priority" => "high"
        },
        "data" => data
      }

      headers = [
        {"Authorization", "key=#{fcm_key}"},
        {"Content-Type", "application/json"}
      ]

      case HTTPoison.post("https://fcm.googleapis.com/fcm/send", Jason.encode!(notification), headers) do
        {:ok, %HTTPoison.Response{status_code: 200}} ->
          {:ok, :sent}

        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          {:error, "FCM returned status #{status_code}: #{body}"}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  # Send APNS notification for iOS
  defp send_apns_notification(token, title, body, data) do
    # For iOS, we'll use FCM for now (works for both iOS and Android)
    # In production, you can configure APNS separately using Pigeon
    apns_mode = Application.get_env(:hotspot_api, :apns_mode, :dev)

    case apns_mode do
      :prod ->
        # In production, use FCM which supports both iOS and Android
        send_fcm_notification(token, title, body, data)

      _ ->
        # In dev mode, just log the notification
        require Logger
        Logger.info("APNS notification (dev mode): #{title} - #{body}")
        Logger.info("Data: #{inspect(data)}")
        {:ok, :sent}
    end
  end

  # Helper functions
  defp format_incident_type("hijacking"), do: "Hijacking"
  defp format_incident_type("mugging"), do: "Mugging"
  defp format_incident_type("accident"), do: "Accident"
  defp format_incident_type(type), do: String.capitalize(type)

  defp format_time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      true -> "#{div(diff, 86400)} days ago"
    end
  end

  defp get_latitude(%Geo.Point{coordinates: {_lng, lat}}), do: to_string(lat)
  defp get_latitude(_), do: "0"

  defp get_longitude(%Geo.Point{coordinates: {lng, _lat}}), do: to_string(lng)
  defp get_longitude(_), do: "0"

  @doc """
  Sends an admin notification to a specific user.
  Used by admins to send custom notifications to users.
  """
  def send_admin_notification(user_id, title, message) do
    # Get user's FCM tokens
    tokens = get_user_tokens(user_id)

    if length(tokens) > 0 do
      # Send to all user's devices
      Task.start(fn ->
        Enum.each(tokens, fn fcm_token ->
          data = %{
            "type" => "admin_notification",
            "title" => title,
            "message" => message
          }

          send_fcm_or_apns(fcm_token.token, fcm_token.platform, title, message, data)
        end)
      end)

      :ok
    else
      {:error, :no_tokens_found}
    end
  end
end
