defmodule HotspotApi.EmergencyServices do
  @moduledoc """
  The EmergencyServices context handles finding nearby emergency services
  like police stations and hospitals using Google Places API.
  """

  require Logger
  alias HotspotApi.Cache

  @google_places_api_key System.get_env("GOOGLE_PLACES_API_KEY")
  @google_places_url "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
  @cache_ttl 3600 # Cache for 1 hour

  @doc """
  Find nearby police stations within a given radius.

  ## Parameters
    - latitude: float
    - longitude: float
    - radius: integer (in meters, default 5000)

  ## Returns
    - {:ok, list of police stations}
    - {:error, reason}
  """
  def find_nearby_police_stations(latitude, longitude, radius \\ 5000) do
    find_nearby_places(latitude, longitude, "police", radius)
  end

  @doc """
  Find nearby hospitals within a given radius.

  ## Parameters
    - latitude: float
    - longitude: float
    - radius: integer (in meters, default 5000)

  ## Returns
    - {:ok, list of hospitals}
    - {:error, reason}
  """
  def find_nearby_hospitals(latitude, longitude, radius \\ 5000) do
    find_nearby_places(latitude, longitude, "hospital", radius)
  end

  @doc """
  Find all nearby emergency services (police stations and hospitals).

  ## Parameters
    - latitude: float
    - longitude: float
    - radius: integer (in meters, default 5000)

  ## Returns
    - {:ok, %{police_stations: [], hospitals: []}}
    - {:error, reason}
  """
  def find_all_emergency_services(latitude, longitude, radius \\ 5000) do
    cache_key = "emergency_services:#{latitude}:#{longitude}:#{radius}"

    case Cache.get(cache_key) do
      {:ok, cached_data} ->
        {:ok, cached_data}

      _ ->
        with {:ok, police_stations} <- find_nearby_police_stations(latitude, longitude, radius),
             {:ok, hospitals} <- find_nearby_hospitals(latitude, longitude, radius) do
          result = %{
            police_stations: police_stations,
            hospitals: hospitals
          }

          Cache.put(cache_key, result, @cache_ttl)
          {:ok, result}
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Calculate distance and estimated travel time to an emergency service.

  ## Parameters
    - from_lat: float
    - from_lng: float
    - to_lat: float
    - to_lng: float

  ## Returns
    - %{distance_meters: integer, distance_text: string, duration_seconds: integer, duration_text: string}
  """
  def calculate_distance_and_eta(from_lat, from_lng, to_lat, to_lng) do
    distance_meters = calculate_haversine_distance(from_lat, from_lng, to_lat, to_lng)

    # Estimate travel time assuming average speed of 40 km/h in urban areas
    duration_seconds = round(distance_meters / 40000 * 3600)

    %{
      distance_meters: round(distance_meters),
      distance_text: format_distance(distance_meters),
      duration_seconds: duration_seconds,
      duration_text: format_duration(duration_seconds)
    }
  end

  # Private functions

  defp find_nearby_places(latitude, longitude, type, radius) do
    cache_key = "places:#{type}:#{latitude}:#{longitude}:#{radius}"

    case Cache.get(cache_key) do
      {:ok, cached_places} ->
        {:ok, cached_places}

      _ ->
        case fetch_from_google_places(latitude, longitude, type, radius) do
          {:ok, places} ->
            Cache.put(cache_key, places, @cache_ttl)
            {:ok, places}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp fetch_from_google_places(latitude, longitude, type, radius) do
    if is_nil(@google_places_api_key) or @google_places_api_key == "" do
      Logger.warning("Google Places API key not configured, returning mock data")
      {:ok, get_mock_places(type, latitude, longitude)}
    else
      params = %{
        location: "#{latitude},#{longitude}",
        radius: radius,
        type: type,
        key: @google_places_api_key
      }

      case Req.get(@google_places_url, params: params) do
        {:ok, %{status: 200, body: %{"status" => "OK", "results" => results}}} ->
          places = Enum.map(results, &parse_place/1)
          {:ok, places}

        {:ok, %{status: 200, body: %{"status" => "ZERO_RESULTS"}}} ->
          {:ok, []}

        {:ok, %{status: 200, body: %{"status" => status}}} ->
          Logger.error("Google Places API error: #{status}")
          {:error, "Google Places API error: #{status}"}

        {:ok, %{status: status}} ->
          Logger.error("Google Places API HTTP error: #{status}")
          {:error, "HTTP error: #{status}"}

        {:error, reason} ->
          Logger.error("Failed to fetch from Google Places API: #{inspect(reason)}")
          {:error, "Failed to fetch emergency services"}
      end
    end
  end

  defp parse_place(place) do
    %{
      place_id: place["place_id"],
      name: place["name"],
      address: place["vicinity"],
      location: %{
        latitude: place["geometry"]["location"]["lat"],
        longitude: place["geometry"]["location"]["lng"]
      },
      rating: place["rating"],
      open_now: get_in(place, ["opening_hours", "open_now"]),
      types: place["types"]
    }
  end

  defp calculate_haversine_distance(lat1, lon1, lat2, lon2) do
    # Earth's radius in meters
    r = 6_371_000

    # Convert degrees to radians
    phi1 = lat1 * :math.pi() / 180
    phi2 = lat2 * :math.pi() / 180
    delta_phi = (lat2 - lat1) * :math.pi() / 180
    delta_lambda = (lon2 - lon1) * :math.pi() / 180

    # Haversine formula
    a =
      :math.sin(delta_phi / 2) * :math.sin(delta_phi / 2) +
        :math.cos(phi1) * :math.cos(phi2) *
          :math.sin(delta_lambda / 2) * :math.sin(delta_lambda / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))

    r * c
  end

  defp format_distance(meters) when meters < 1000 do
    "#{round(meters)} m"
  end

  defp format_distance(meters) do
    km = meters / 1000
    "#{Float.round(km, 1)} km"
  end

  defp format_duration(seconds) when seconds < 60 do
    "#{seconds} sec"
  end

  defp format_duration(seconds) when seconds < 3600 do
    minutes = div(seconds, 60)
    "#{minutes} min"
  end

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    "#{hours} hr #{minutes} min"
  end

  # Mock data for development/testing when API key is not configured
  defp get_mock_places("police", lat, lng) do
    [
      %{
        place_id: "mock_police_1",
        name: "Central Police Station",
        address: "123 Main Street",
        location: %{
          latitude: lat + 0.01,
          longitude: lng + 0.01
        },
        rating: 4.2,
        open_now: true,
        types: ["police", "point_of_interest"]
      },
      %{
        place_id: "mock_police_2",
        name: "North Police Station",
        address: "456 North Avenue",
        location: %{
          latitude: lat + 0.02,
          longitude: lng - 0.01
        },
        rating: 4.0,
        open_now: true,
        types: ["police", "point_of_interest"]
      }
    ]
  end

  defp get_mock_places("hospital", lat, lng) do
    [
      %{
        place_id: "mock_hospital_1",
        name: "City General Hospital",
        address: "789 Hospital Road",
        location: %{
          latitude: lat - 0.01,
          longitude: lng + 0.02
        },
        rating: 4.5,
        open_now: true,
        types: ["hospital", "health", "point_of_interest"]
      },
      %{
        place_id: "mock_hospital_2",
        name: "Emergency Medical Center",
        address: "321 Emergency Lane",
        location: %{
          latitude: lat + 0.015,
          longitude: lng + 0.015
        },
        rating: 4.3,
        open_now: true,
        types: ["hospital", "health", "point_of_interest"]
      }
    ]
  end

  defp get_mock_places(_, _lat, _lng), do: []
end
