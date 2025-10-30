defmodule HotspotApi.Incidents do
  @moduledoc """
  The Incidents context.
  """

  import Ecto.Query, warn: false
  import Geo.PostGIS
  alias HotspotApi.Repo

  alias HotspotApi.Incidents.Incident

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

    %Incident{}
    |> Incident.changeset(attrs)
    |> Repo.insert()
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
end
