defmodule HotspotApi.Incidents do
  @moduledoc """
  The Incidents context.
  """

  import Ecto.Query, warn: false
  import Geo.PostGIS
  alias HotspotApi.Repo

  alias HotspotApi.Incidents.Incident
  alias HotspotApi.Incidents.IncidentVerification

  @doc """
  Returns the list of incidents that haven't expired.

  ## Examples

      iex> list_incidents()
      [%Incident{}, ...]

  """
  def list_incidents do
    now = DateTime.utc_now()

    Incident
    |> where([i], i.expires_at > ^now)
    |> order_by([i], desc: i.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single incident.

  Raises `Ecto.NoResultsError` if the Incident does not exist.

  ## Examples

      iex> get_incident!(123)
      %Incident{}

      iex> get_incident!(456)
      ** (Ecto.NoResultsError)

  """
  def get_incident!(id), do: Repo.get!(Incident, id)

  @doc """
  Creates an incident with automatic expiration set to 48 hours from now.

  ## Examples

      iex> create_incident(%{type: "hijacking", latitude: -26.2041, longitude: 28.0473, user_id: "..."})
      {:ok, %Incident{}}

      iex> create_incident(%{type: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def create_incident(attrs) do
    # Normalize to string keys and set expiration to 48 hours from now if not provided
    attrs =
      attrs
      |> normalize_keys()
      |> Map.put_new("expires_at", DateTime.add(DateTime.utc_now(), 48, :hour))

    result =
      %Incident{}
      |> Incident.changeset(attrs)
      |> Repo.insert()

    # Broadcast new incident to Phoenix Channels
    case result do
      {:ok, incident} ->
        HotspotApiWeb.IncidentChannel.broadcast_new_incident(incident)
        {:ok, incident}

      error ->
        error
    end
  end

  # Normalize map keys to strings
  defp normalize_keys(attrs) when is_map(attrs) do
    Enum.reduce(attrs, %{}, fn {key, value}, acc ->
      string_key = if is_atom(key), do: Atom.to_string(key), else: key
      Map.put(acc, string_key, value)
    end)
  end

  @doc """
  Lists incidents near a given location using PostGIS ST_DWithin.

  ## Parameters
    - latitude: Latitude of the center point
    - longitude: Longitude of the center point
    - radius_meters: Search radius in meters (default: 5000)

  ## Examples

      iex> list_nearby(-26.2041, 28.0473, 5000)
      [%Incident{}, ...]

  """
  def list_nearby(latitude, longitude, radius_meters \\ 5000) do
    point = %Geo.Point{coordinates: {longitude, latitude}, srid: 4326}
    now = DateTime.utc_now()

    Incident
    |> where([i], i.expires_at > ^now)
    |> where([i], st_dwithin_in_meters(i.location, ^point, ^radius_meters))
    |> order_by([i], desc: i.inserted_at)
    |> Repo.all()
    |> Enum.map(&add_distance(&1, point))
  end

  @doc """
  Lists incidents near a given location with pagination and filtering.

  ## Parameters
    - latitude: Latitude of the center point
    - longitude: Longitude of the center point
    - radius_meters: Search radius in meters (default: 5000)
    - opts: Keyword list with optional filters
      - :type - Filter by incident type (hijacking, mugging, accident)
      - :time_range - Filter by time range (24h, 7d, all)
      - :page - Page number (default: 1)
      - :page_size - Items per page (default: 20)

  ## Examples

      iex> list_nearby_paginated(-26.2041, 28.0473, 5000, type: "hijacking", time_range: "24h", page: 1)
      %{incidents: [%Incident{}, ...], total_count: 42, page: 1, page_size: 20, total_pages: 3}

  """
  def list_nearby_paginated(latitude, longitude, radius_meters \\ 5000, opts \\ []) do
    point = %Geo.Point{coordinates: {longitude, latitude}, srid: 4326}
    now = DateTime.utc_now()

    # Extract options with defaults
    type_filter = Keyword.get(opts, :type)
    time_range = Keyword.get(opts, :time_range, "all")
    page = max(Keyword.get(opts, :page, 1), 1)
    page_size = Keyword.get(opts, :page_size, 20)

    # Build base query
    query =
      Incident
      |> where([i], i.expires_at > ^now)
      |> where([i], st_dwithin_in_meters(i.location, ^point, ^radius_meters))

    # Apply type filter
    query = if type_filter && type_filter != "all" do
      where(query, [i], i.type == ^type_filter)
    else
      query
    end

    # Apply time range filter
    query = case time_range do
      "24h" ->
        cutoff = DateTime.add(now, -24, :hour)
        where(query, [i], i.inserted_at > ^cutoff)
      "7d" ->
        cutoff = DateTime.add(now, -7, :day)
        where(query, [i], i.inserted_at > ^cutoff)
      _ ->
        query
    end

    # Get total count
    total_count = Repo.aggregate(query, :count, :id)

    # Apply pagination and ordering
    incidents =
      query
      |> order_by([i], desc: i.inserted_at)
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> Repo.all()
      |> Enum.map(&add_distance(&1, point))

    total_pages = ceil(total_count / page_size)

    %{
      incidents: incidents,
      total_count: total_count,
      page: page,
      page_size: page_size,
      total_pages: total_pages
    }
  end

  @doc """
  Updates a incident.

  ## Examples

      iex> update_incident(incident, %{field: new_value})
      {:ok, %Incident{}}

      iex> update_incident(incident, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_incident(%Incident{} = incident, attrs) do
    incident
    |> Incident.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a incident.

  ## Examples

      iex> delete_incident(incident)
      {:ok, %Incident{}}

      iex> delete_incident(incident)
      {:error, %Ecto.Changeset{}}

  """
  def delete_incident(%Incident{} = incident) do
    Repo.delete(incident)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking incident changes.

  ## Examples

      iex> change_incident(incident)
      %Ecto.Changeset{data: %Incident{}}

  """
  def change_incident(%Incident{} = incident, attrs \\ %{}) do
    Incident.changeset(incident, attrs)
  end

  # Private helper to add distance to incident
  defp add_distance(%Incident{location: location} = incident, point) do
    distance = calculate_distance(location, point)
    Map.put(incident, :distance, distance)
  end

  # Calculate distance in meters using Haversine formula
  defp calculate_distance(%Geo.Point{coordinates: {lng1, lat1}}, %Geo.Point{coordinates: {lng2, lat2}}) do
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

  @doc """
  Verifies an incident by a user. Creates a verification record and updates the incident's verification count.
  Automatically marks the incident as verified if it receives 3+ upvotes within 2 hours of creation.

  ## Parameters
    - incident_id: The ID of the incident to verify
    - user_id: The ID of the user verifying the incident

  ## Returns
    - {:ok, %IncidentVerification{}} on success
    - {:error, %Ecto.Changeset{}} if validation fails (duplicate vote, self-verification, etc.)

  ## Examples

      iex> verify_incident("incident-id", "user-id")
      {:ok, %IncidentVerification{}}

      iex> verify_incident("incident-id", "same-user-id")
      {:error, %Ecto.Changeset{errors: [user_id: {"You cannot verify your own incident", []}]}}

  """
  def verify_incident(incident_id, user_id) do
    Repo.transaction(fn ->
      # Create the verification record
      verification_result =
        %IncidentVerification{}
        |> IncidentVerification.changeset(%{incident_id: incident_id, user_id: user_id})
        |> Repo.insert()

      case verification_result do
        {:ok, verification} ->
          # Increment verification count
          incident = Repo.get!(Incident, incident_id)
          new_count = incident.verification_count + 1

          # Check if incident should be auto-verified (3+ upvotes within 2 hours)
          two_hours_ago = DateTime.add(DateTime.utc_now(), -2, :hour)
          should_verify = new_count >= 3 && DateTime.compare(incident.inserted_at, two_hours_ago) == :gt

          # Update incident
          incident
          |> Incident.changeset(%{
            verification_count: new_count,
            is_verified: should_verify || incident.is_verified
          })
          |> Repo.update!()

          verification

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Gets all verifications for a specific incident.

  ## Examples

      iex> get_incident_verifications("incident-id")
      [%IncidentVerification{}, ...]

  """
  def get_incident_verifications(incident_id) do
    IncidentVerification
    |> where([v], v.incident_id == ^incident_id)
    |> Repo.all()
  end

  @doc """
  Checks if a user has already verified a specific incident.

  ## Examples

      iex> user_verified_incident?("incident-id", "user-id")
      true

  """
  def user_verified_incident?(incident_id, user_id) do
    IncidentVerification
    |> where([v], v.incident_id == ^incident_id and v.user_id == ^user_id)
    |> Repo.exists?()
  end

  @doc """
  Deletes expired incidents (those with zero verifications after 48 hours).
  This function is meant to be called by the IncidentExpiryWorker.

  ## Examples

      iex> delete_expired_incidents()
      {5, nil}  # Returns number of deleted incidents

  """
  def delete_expired_incidents do
    now = DateTime.utc_now()

    # Delete incidents that have expired and have zero verifications
    Incident
    |> where([i], i.expires_at <= ^now and i.verification_count == 0)
    |> Repo.delete_all()
  end

  @doc """
  Generates heatmap data by clustering incidents from the past 7 days using PostGIS ST_ClusterDBSCAN.
  Returns cluster centers with incident counts and dominant incident type.
  Only returns clusters with 5 or more incidents.

  ## Examples

      iex> get_heatmap_data()
      [
        %{
          center: %{latitude: -26.2041, longitude: 28.0473},
          incident_count: 12,
          dominant_type: "hijacking",
          radius: 500
        },
        ...
      ]

  """
  def get_heatmap_data do
    seven_days_ago = DateTime.add(DateTime.utc_now(), -7, :day)
    now = DateTime.utc_now()

    # Query incidents from past 7 days using PostGIS ST_ClusterDBSCAN
    # eps = 0.01 degrees (~1.1km at equator)
    # minpoints = 5 (minimum incidents to form a cluster)
    query = """
    WITH clustered_incidents AS (
      SELECT
        id,
        type,
        location,
        ST_ClusterDBSCAN(location, eps := 0.01, minpoints := 5) OVER () AS cluster_id
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
      HAVING COUNT(*) >= 5
    )
    SELECT
      ST_Y(center) AS latitude,
      ST_X(center) AS longitude,
      incident_count,
      dominant_type
    FROM cluster_stats
    ORDER BY incident_count DESC
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
            radius: calculate_cluster_radius(count)
          }
        end)

      {:error, _} ->
        []
    end
  end

  # Calculate visual radius for heat zone based on incident count
  # More incidents = larger circle
  defp calculate_cluster_radius(count) when count >= 20, do: 1000
  defp calculate_cluster_radius(count) when count >= 15, do: 800
  defp calculate_cluster_radius(count) when count >= 10, do: 600
  defp calculate_cluster_radius(count) when count >= 5, do: 400
  defp calculate_cluster_radius(_count), do: 300
end
