defmodule HotspotApi.Analytics do
  @moduledoc """
  The Analytics context for generating incident statistics and patterns.
  """

  import Ecto.Query, warn: false
  alias HotspotApi.Repo
  alias HotspotApi.Incidents.Incident

  @doc """
  Returns the top 5 hotspot areas with the highest incident counts from the past 7 days.
  Uses PostGIS ST_ClusterDBSCAN to identify geographic clusters.

  ## Examples

      iex> get_top_hotspots()
      [
        %{
          center: %{latitude: -26.2041, longitude: 28.0473},
          incident_count: 25,
          dominant_type: "hijacking",
          area_name: "Johannesburg CBD"
        },
        ...
      ]

  """
  def get_top_hotspots do
    seven_days_ago = DateTime.add(DateTime.utc_now(), -7, :day)
    now = DateTime.utc_now()

    query = """
    WITH clustered_incidents AS (
      SELECT
        id,
        type,
        location,
        ST_ClusterDBSCAN(location, eps := 0.01, minpoints := 3) OVER () AS cluster_id
      FROM incidents
      WHERE inserted_at >= $1
        AND expires_at > $2
    ),
    cluster_stats AS (
      SELECT
        cluster_id,
        COUNT(*) AS incident_count,
        ST_Centroid(ST_Collect(location)) AS center,
        MODE() WITHIN GROUP (ORDER BY type) AS dominant_type
      FROM clustered_incidents
      WHERE cluster_id IS NOT NULL
      GROUP BY cluster_id
    )
    SELECT
      ST_Y(center) AS latitude,
      ST_X(center) AS longitude,
      incident_count,
      dominant_type
    FROM cluster_stats
    ORDER BY incident_count DESC
    LIMIT 5
    """

    case Ecto.Adapters.SQL.query(Repo, query, [seven_days_ago, now]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [lat, lng, count, type] ->
          %{
            center: %{
              latitude: lat,
              longitude: lng
            },
            incident_count: count,
            dominant_type: type,
            area_name: get_area_name(lat, lng)
          }
        end)

      {:error, _} ->
        []
    end
  end

  @doc """
  Returns time pattern analysis showing peak hours for each incident type.
  Analyzes incidents from the past 30 days.

  ## Examples

      iex> get_time_patterns()
      [
        %{
          hour: 18,
          hijacking_count: 15,
          mugging_count: 8,
          accident_count: 12,
          total_count: 35
        },
        ...
      ]

  """
  def get_time_patterns do
    thirty_days_ago = DateTime.add(DateTime.utc_now(), -30, :day)
    now = DateTime.utc_now()

    query = """
    SELECT
      EXTRACT(HOUR FROM inserted_at)::integer AS hour,
      COUNT(*) FILTER (WHERE type = 'hijacking') AS hijacking_count,
      COUNT(*) FILTER (WHERE type = 'mugging') AS mugging_count,
      COUNT(*) FILTER (WHERE type = 'accident') AS accident_count,
      COUNT(*) AS total_count
    FROM incidents
    WHERE inserted_at >= $1
      AND expires_at > $2
    GROUP BY hour
    ORDER BY hour
    """

    case Ecto.Adapters.SQL.query(Repo, query, [thirty_days_ago, now]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [hour, hijacking, mugging, accident, total] ->
          %{
            hour: hour,
            hijacking_count: hijacking,
            mugging_count: mugging,
            accident_count: accident,
            total_count: total
          }
        end)

      {:error, _} ->
        []
    end
  end

  @doc """
  Returns weekly trend data showing incident counts over the past specified number of weeks.
  Groups incidents by week and type.

  ## Parameters
    - weeks: Number of weeks to analyze (default: 4)

  ## Examples

      iex> get_weekly_trends(4)
      [
        %{
          week_start: ~U[2024-10-07 00:00:00Z],
          week_label: "Oct 7",
          hijacking_count: 45,
          mugging_count: 32,
          accident_count: 28,
          total_count: 105
        },
        ...
      ]

  """
  def get_weekly_trends(weeks \\ 4) do
    start_date = DateTime.add(DateTime.utc_now(), -weeks * 7, :day)
    now = DateTime.utc_now()

    query = """
    SELECT
      date_trunc('week', inserted_at) AS week_start,
      COUNT(*) FILTER (WHERE type = 'hijacking') AS hijacking_count,
      COUNT(*) FILTER (WHERE type = 'mugging') AS mugging_count,
      COUNT(*) FILTER (WHERE type = 'accident') AS accident_count,
      COUNT(*) AS total_count
    FROM incidents
    WHERE inserted_at >= $1
      AND expires_at > $2
    GROUP BY week_start
    ORDER BY week_start
    """

    case Ecto.Adapters.SQL.query(Repo, query, [start_date, now]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [week_start, hijacking, mugging, accident, total] ->
          %{
            week_start: week_start,
            week_label: format_week_label(week_start),
            hijacking_count: hijacking,
            mugging_count: mugging,
            accident_count: accident,
            total_count: total
          }
        end)

      {:error, _} ->
        []
    end
  end

  @doc """
  Returns comprehensive analytics summary including total counts, verification rate, and active users.

  ## Examples

      iex> get_analytics_summary()
      %{
        total_incidents: 1250,
        active_incidents: 342,
        verification_rate: 0.68,
        top_incident_type: "hijacking",
        incidents_today: 45
      }

  """
  def get_analytics_summary do
    now = DateTime.utc_now()
    today_start = DateTime.new!(Date.utc_today(), ~T[00:00:00])

    # Get total and active incident counts
    total_query = from(i in Incident, select: count(i.id))
    active_query = from(i in Incident, where: i.expires_at > ^now, select: count(i.id))
    today_query = from(i in Incident, where: i.inserted_at >= ^today_start, select: count(i.id))

    total_incidents = Repo.one(total_query) || 0
    active_incidents = Repo.one(active_query) || 0
    incidents_today = Repo.one(today_query) || 0

    # Calculate verification rate
    verified_query = from(i in Incident, where: i.is_verified == true, select: count(i.id))
    verified_count = Repo.one(verified_query) || 0
    verification_rate = if total_incidents > 0, do: verified_count / total_incidents, else: 0.0

    # Get most common incident type
    type_query = """
    SELECT type, COUNT(*) as count
    FROM incidents
    WHERE expires_at > $1
    GROUP BY type
    ORDER BY count DESC
    LIMIT 1
    """

    top_type = case Ecto.Adapters.SQL.query(Repo, type_query, [now]) do
      {:ok, %{rows: [[type, _count] | _]}} -> type
      _ -> nil
    end

    %{
      total_incidents: total_incidents,
      active_incidents: active_incidents,
      verification_rate: Float.round(verification_rate, 2),
      top_incident_type: top_type,
      incidents_today: incidents_today
    }
  end

  # Helper function to get area name from coordinates
  # In a real implementation, this would use reverse geocoding
  defp get_area_name(_lat, _lng) do
    # Placeholder - would integrate with Google Maps Geocoding API or similar
    "Area"
  end

  # Format week start date as readable label
  defp format_week_label(datetime) do
    datetime
    |> DateTime.to_date()
    |> Calendar.strftime("%b %-d")
  end
end
