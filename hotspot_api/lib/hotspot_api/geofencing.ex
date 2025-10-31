defmodule HotspotApi.Geofencing do
  @moduledoc """
  The Geofencing context for managing hotspot zones and user zone tracking.
  """

  import Ecto.Query, warn: false
  import Geo.PostGIS
  alias HotspotApi.Repo

  alias HotspotApi.Geofencing.HotspotZone
  alias HotspotApi.Geofencing.UserZoneTracking
  alias HotspotApi.Incidents

  @doc """
  Returns the list of active hotspot zones.

  ## Examples

      iex> list_active_zones()
      [%HotspotZone{}, ...]

  """
  def list_active_zones do
    HotspotZone
    |> where([z], z.is_active == true)
    |> order_by([z], desc: z.incident_count)
    |> Repo.all()
  end

  @doc """
  Gets a single hotspot zone.

  Raises `Ecto.NoResultsError` if the Hotspot zone does not exist.

  ## Examples

      iex> get_zone!(123)
      %HotspotZone{}

      iex> get_zone!(456)
      ** (Ecto.NoResultsError)

  """
  def get_zone!(id), do: Repo.get!(HotspotZone, id)

  @doc """
  Creates a hotspot zone.

  ## Examples

      iex> create_zone(%{zone_type: "hijacking", latitude: -26.2041, longitude: 28.0473, ...})
      {:ok, %HotspotZone{}}

      iex> create_zone(%{zone_type: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def create_zone(attrs \\ %{}) do
    %HotspotZone{}
    |> HotspotZone.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a hotspot zone.

  ## Examples

      iex> update_zone(zone, %{field: new_value})
      {:ok, %HotspotZone{}}

      iex> update_zone(zone, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_zone(%HotspotZone{} = zone, attrs) do
    zone
    |> HotspotZone.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a hotspot zone.

  ## Examples

      iex> delete_zone(zone)
      {:ok, %HotspotZone{}}

      iex> delete_zone(zone)
      {:error, %Ecto.Changeset{}}

  """
  def delete_zone(%HotspotZone{} = zone) do
    Repo.delete(zone)
  end

  @doc """
  Updates hotspot zones based on incident clustering.
  This function should be called periodically (every 10 minutes) by the ZoneUpdateWorker.

  ## Algorithm:
  1. Get incidents from past 7 days
  2. Cluster incidents by type using ST_ClusterDBSCAN (1km radius, min 5 incidents)
  3. Create or update zones for each cluster
  4. Calculate risk levels based on incident count
  5. Dissolve zones with < 3 incidents in past 7 days

  ## Examples

      iex> update_zones()
      {:ok, %{created: 3, updated: 2, dissolved: 1}}

  """
  def update_zones do
    seven_days_ago = DateTime.add(DateTime.utc_now(), -7, :day)
    now = DateTime.utc_now()

    # Query incidents from past 7 days grouped by type using PostGIS ST_ClusterDBSCAN
    query = """
    WITH clustered_incidents AS (
      SELECT
        id,
        type,
        location,
        inserted_at,
        ST_ClusterDBSCAN(location, eps := 0.01, minpoints := 5) OVER (PARTITION BY type) AS cluster_id
      FROM incidents
      WHERE inserted_at >= $1
        AND expires_at > $2
    ),
    cluster_stats AS (
      SELECT
        type AS zone_type,
        cluster_id,
        COUNT(*) AS incident_count,
        ST_Centroid(ST_Collect(location)) AS center,
        MAX(inserted_at) AS last_incident_at
      FROM clustered_incidents
      WHERE cluster_id IS NOT NULL
      GROUP BY type, cluster_id
      HAVING COUNT(*) >= 5
    )
    SELECT
      zone_type,
      ST_Y(center) AS latitude,
      ST_X(center) AS longitude,
      incident_count,
      last_incident_at
    FROM cluster_stats
    ORDER BY incident_count DESC
    """

    case Ecto.Adapters.SQL.query(Repo, query, [seven_days_ago, now]) do
      {:ok, %{rows: rows}} ->
        stats = %{created: 0, updated: 0, dissolved: 0}

        # Process each cluster
        stats = Enum.reduce(rows, stats, fn [zone_type, lat, lng, count, last_incident_at], acc ->
          risk_level = calculate_risk_level(count)

          # Check if a zone already exists at this location
          existing_zone = find_zone_at_location(lat, lng, zone_type)

          case existing_zone do
            nil ->
              # Create new zone
              {:ok, _zone} = create_zone(%{
                zone_type: zone_type,
                latitude: lat,
                longitude: lng,
                radius_meters: 1000,
                incident_count: count,
                risk_level: risk_level,
                is_active: true,
                last_incident_at: last_incident_at
              })
              %{acc | created: acc.created + 1}

            zone ->
              # Update existing zone
              {:ok, _zone} = update_zone(zone, %{
                incident_count: count,
                risk_level: risk_level,
                is_active: true,
                last_incident_at: last_incident_at
              })
              %{acc | updated: acc.updated + 1}
          end
        end)

        # Dissolve zones with < 3 incidents in past 7 days
        dissolved_count = dissolve_stale_zones()
        stats = %{stats | dissolved: dissolved_count}

        {:ok, stats}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Calculate risk level based on incident count.

  ## Risk Levels:
  - Low: 3-5 incidents
  - Medium: 6-10 incidents
  - High: 11-20 incidents
  - Critical: 20+ incidents

  ## Examples

      iex> calculate_risk_level(4)
      "low"

      iex> calculate_risk_level(15)
      "high"

  """
  def calculate_risk_level(incident_count) when incident_count >= 20, do: "critical"
  def calculate_risk_level(incident_count) when incident_count >= 11, do: "high"
  def calculate_risk_level(incident_count) when incident_count >= 6, do: "medium"
  def calculate_risk_level(_incident_count), do: "low"

  # Find a zone at a specific location (within 500m radius) of the same type.
  # Used to determine if we should update an existing zone or create a new one.
  defp find_zone_at_location(latitude, longitude, zone_type) do
    point = %Geo.Point{coordinates: {longitude, latitude}, srid: 4326}

    HotspotZone
    |> where([z], z.zone_type == ^zone_type)
    |> where([z], st_dwithin_in_meters(z.center_location, ^point, 500))
    |> limit(1)
    |> Repo.one()
  end

  # Dissolve zones with < 3 incidents in past 7 days by marking them as inactive.
  # Returns the count of dissolved zones.
  defp dissolve_stale_zones do
    seven_days_ago = DateTime.add(DateTime.utc_now(), -7, :day)

    # For each active zone, count incidents in past 7 days
    active_zones = list_active_zones()

    Enum.reduce(active_zones, 0, fn zone, count ->
      %Geo.Point{coordinates: {lng, lat}} = zone.center_location

      # Count incidents near this zone from past 7 days
      incident_count = Incidents.list_nearby(lat, lng, zone.radius_meters)
        |> Enum.filter(fn incident ->
          incident.type == zone.zone_type &&
          DateTime.compare(incident.inserted_at, seven_days_ago) == :gt
        end)
        |> length()

      if incident_count < 3 do
        # Dissolve zone by marking as inactive
        update_zone(zone, %{is_active: false})
        count + 1
      else
        count
      end
    end)
  end

  @doc """
  Check if a location is within any active hotspot zone.
  Returns a list of zones that contain the location.

  ## Examples

      iex> check_location(-26.2041, 28.0473)
      [%HotspotZone{}, ...]

  """
  def check_location(latitude, longitude) do
    point = %Geo.Point{coordinates: {longitude, latitude}, srid: 4326}

    HotspotZone
    |> where([z], z.is_active == true)
    |> where([z], st_dwithin_in_meters(z.center_location, ^point, z.radius_meters))
    |> Repo.all()
  end

  @doc """
  Track user entry into a zone.
  Creates a tracking record if the user is not already in the zone.

  ## Examples

      iex> track_zone_entry("user-id", "zone-id")
      {:ok, %UserZoneTracking{}}

  """
  def track_zone_entry(user_id, zone_id) do
    # Check if user already has an active tracking record for this zone
    existing = UserZoneTracking
      |> where([t], t.user_id == ^user_id and t.zone_id == ^zone_id and is_nil(t.exited_at))
      |> Repo.one()

    case existing do
      nil ->
        # Create new tracking record
        %UserZoneTracking{}
        |> UserZoneTracking.changeset(%{
          user_id: user_id,
          zone_id: zone_id,
          entered_at: DateTime.utc_now(),
          notification_sent: false
        })
        |> Repo.insert()

      tracking ->
        # User already in zone
        {:ok, tracking}
    end
  end

  @doc """
  Track user exit from a zone.
  Updates the tracking record with exit time.

  ## Examples

      iex> track_zone_exit("user-id", "zone-id")
      {:ok, %UserZoneTracking{}}

  """
  def track_zone_exit(user_id, zone_id) do
    # Find active tracking record
    tracking = UserZoneTracking
      |> where([t], t.user_id == ^user_id and t.zone_id == ^zone_id and is_nil(t.exited_at))
      |> Repo.one()

    case tracking do
      nil ->
        {:error, :not_found}

      tracking ->
        tracking
        |> UserZoneTracking.changeset(%{exited_at: DateTime.utc_now()})
        |> Repo.update()
    end
  end

  @doc """
  Mark notification as sent for a zone entry.

  ## Examples

      iex> mark_notification_sent(tracking)
      {:ok, %UserZoneTracking{}}

  """
  def mark_notification_sent(%UserZoneTracking{} = tracking) do
    tracking
    |> UserZoneTracking.changeset(%{notification_sent: true})
    |> Repo.update()
  end

  @doc """
  Get zones that a user is currently in (no exit time).

  ## Examples

      iex> get_user_current_zones("user-id")
      [%HotspotZone{}, ...]

  """
  def get_user_current_zones(user_id) do
    query = from t in UserZoneTracking,
      join: z in HotspotZone, on: t.zone_id == z.id,
      where: t.user_id == ^user_id and is_nil(t.exited_at),
      select: z

    Repo.all(query)
  end

  @doc """
  Check for zones that user is approaching (within 500m for premium users).
  Returns zones within 500m but outside the zone radius.

  ## Examples

      iex> check_approaching_zones(-26.2041, 28.0473, true)
      [%HotspotZone{}, ...]

  """
  def check_approaching_zones(latitude, longitude, is_premium) do
    if is_premium do
      point = %Geo.Point{coordinates: {longitude, latitude}, srid: 4326}

      # Find zones within 500m + zone radius
      HotspotZone
      |> where([z], z.is_active == true)
      |> where([z], st_dwithin_in_meters(z.center_location, ^point, z.radius_meters + 500))
      |> Repo.all()
      |> Enum.filter(fn zone ->
        # Filter to only zones user is NOT already in (approaching but not entered)
        %Geo.Point{coordinates: {lng, lat}} = zone.center_location
        distance = calculate_distance(latitude, longitude, lat, lng)
        distance > zone.radius_meters && distance <= zone.radius_meters + 500
      end)
    else
      []
    end
  end

  # Calculate distance in meters using Haversine formula
  defp calculate_distance(lat1, lng1, lat2, lng2) do
    r = 6371000 # Earth's radius in meters

    phi1 = lat1 * :math.pi() / 180
    phi2 = lat2 * :math.pi() / 180
    delta_phi = (lat2 - lat1) * :math.pi() / 180
    delta_lambda = (lng2 - lng1) * :math.pi() / 180

    a = :math.sin(delta_phi / 2) * :math.sin(delta_phi / 2) +
        :math.cos(phi1) * :math.cos(phi2) *
        :math.sin(delta_lambda / 2) * :math.sin(delta_lambda / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))

    round(r * c)
  end
end
