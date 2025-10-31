defmodule HotspotApiWeb.EmergencyServicesController do
  use HotspotApiWeb, :controller

  alias HotspotApi.EmergencyServices

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  GET /api/emergency-services/nearby

  Find nearby emergency services (police stations and hospitals).

  Query params:
    - lat: latitude (required)
    - lng: longitude (required)
    - radius: search radius in meters (optional, default 5000)
  """
  def nearby(conn, %{"lat" => lat_str, "lng" => lng_str} = params) do
    with {:ok, latitude} <- parse_float(lat_str),
         {:ok, longitude} <- parse_float(lng_str),
         radius <- parse_radius(params["radius"]),
         {:ok, services} <- EmergencyServices.find_all_emergency_services(latitude, longitude, radius) do
      # Calculate distance and ETA for each service from user's location
      user_location = %{latitude: latitude, longitude: longitude}

      enriched_services = %{
        police_stations: enrich_with_distance(services.police_stations, user_location),
        hospitals: enrich_with_distance(services.hospitals, user_location)
      }

      conn
      |> put_status(:ok)
      |> json(%{
        data: enriched_services,
        user_location: user_location
      })
    else
      {:error, :invalid_latitude} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid latitude parameter"})

      {:error, :invalid_longitude} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid longitude parameter"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to fetch emergency services: #{reason}"})
    end
  end

  def nearby(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameters: lat and lng"})
  end

  @doc """
  GET /api/emergency-services/police

  Find nearby police stations only.
  """
  def police_stations(conn, %{"lat" => lat_str, "lng" => lng_str} = params) do
    with {:ok, latitude} <- parse_float(lat_str),
         {:ok, longitude} <- parse_float(lng_str),
         radius <- parse_radius(params["radius"]),
         {:ok, stations} <- EmergencyServices.find_nearby_police_stations(latitude, longitude, radius) do
      user_location = %{latitude: latitude, longitude: longitude}
      enriched_stations = enrich_with_distance(stations, user_location)

      conn
      |> put_status(:ok)
      |> json(%{
        data: enriched_stations,
        user_location: user_location
      })
    else
      {:error, :invalid_latitude} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid latitude parameter"})

      {:error, :invalid_longitude} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid longitude parameter"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to fetch police stations: #{reason}"})
    end
  end

  @doc """
  GET /api/emergency-services/hospitals

  Find nearby hospitals only.
  """
  def hospitals(conn, %{"lat" => lat_str, "lng" => lng_str} = params) do
    with {:ok, latitude} <- parse_float(lat_str),
         {:ok, longitude} <- parse_float(lng_str),
         radius <- parse_radius(params["radius"]),
         {:ok, hospitals} <- EmergencyServices.find_nearby_hospitals(latitude, longitude, radius) do
      user_location = %{latitude: latitude, longitude: longitude}
      enriched_hospitals = enrich_with_distance(hospitals, user_location)

      conn
      |> put_status(:ok)
      |> json(%{
        data: enriched_hospitals,
        user_location: user_location
      })
    else
      {:error, :invalid_latitude} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid latitude parameter"})

      {:error, :invalid_longitude} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid longitude parameter"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to fetch hospitals: #{reason}"})
    end
  end

  # Private functions

  defp parse_float(value) when is_float(value), do: {:ok, value}
  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> {:error, :invalid_float}
    end
  end
  defp parse_float(_), do: {:error, :invalid_float}

  defp parse_radius(nil), do: 5000
  defp parse_radius(radius) when is_integer(radius), do: radius
  defp parse_radius(radius) when is_binary(radius) do
    case Integer.parse(radius) do
      {int, ""} -> int
      _ -> 5000
    end
  end
  defp parse_radius(_), do: 5000

  defp enrich_with_distance(services, user_location) do
    Enum.map(services, fn service ->
      distance_info = EmergencyServices.calculate_distance_and_eta(
        user_location.latitude,
        user_location.longitude,
        service.location.latitude,
        service.location.longitude
      )

      Map.merge(service, distance_info)
    end)
    |> Enum.sort_by(& &1.distance_meters)
  end
end
