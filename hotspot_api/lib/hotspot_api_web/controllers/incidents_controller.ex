defmodule HotspotApiWeb.IncidentsController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Incidents
  alias HotspotApi.Incidents.Incident
  alias HotspotApi.Storage.Appwrite

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  Upload a photo to Appwrite Storage and return the file ID.
  """
  def upload_photo(conn, %{"photo" => %Plug.Upload{} = upload}) do
    with {:ok, file_binary} <- File.read(upload.path),
         {:ok, file_id} <- Appwrite.upload_file(file_binary, upload.filename, upload.content_type) do
      photo_url = Appwrite.get_file_url(file_id)

      conn
      |> put_status(:created)
      |> json(%{
        file_id: file_id,
        photo_url: photo_url
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  def upload_photo(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "No photo file provided"})
  end

  @doc """
  Create a new incident report
  """
  def create(conn, %{"incident" => incident_params}) do
    # Get user_id from Guardian claims
    user_id = Guardian.Plug.current_resource(conn).id
    incident_params = Map.put(incident_params, "user_id", user_id)

    case Incidents.create_incident(incident_params) do
      {:ok, %Incident{} = incident} ->
        conn
        |> put_status(:created)
        |> render(:show, incident: incident)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  List incidents near a location
  """
  def nearby(conn, params) do
    with {:ok, latitude} <- parse_float(params["lat"], "latitude"),
         {:ok, longitude} <- parse_float(params["lng"], "longitude") do
      radius = parse_radius(params["radius"])
      incidents = Incidents.list_nearby(latitude, longitude, radius)

      render(conn, :index, incidents: incidents)
    else
      {:error, field} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid #{field} parameter"})
    end
  end

  defp parse_float(nil, field), do: {:error, field}
  defp parse_float(value, _field) when is_float(value), do: {:ok, value}
  defp parse_float(value, field) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> {:ok, float}
      :error -> {:error, field}
    end
  end
  defp parse_float(_value, field), do: {:error, field}

  defp parse_radius(nil), do: 5000
  defp parse_radius(radius) when is_integer(radius), do: radius
  defp parse_radius(radius) when is_binary(radius) do
    case Integer.parse(radius) do
      {int, _} -> int
      :error -> 5000
    end
  end
  defp parse_radius(_), do: 5000
end
