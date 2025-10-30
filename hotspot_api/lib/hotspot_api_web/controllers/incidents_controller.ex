defmodule HotspotApiWeb.IncidentsController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Incidents
  alias HotspotApi.Incidents.Incident

  action_fallback HotspotApiWeb.FallbackController

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
    with {:ok, latitude} <- parse_float(params["lat"]),
         {:ok, longitude} <- parse_float(params["lng"]) do
      radius = parse_radius(params["radius"])
      incidents = Incidents.list_nearby(latitude, longitude, radius)

      render(conn, :index, incidents: incidents)
    else
      {:error, :invalid_latitude} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid latitude parameter"})

      {:error, :invalid_longitude} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid longitude parameter"})
    end
  end

  defp parse_float(nil), do: {:error, :invalid}
  defp parse_float(value) when is_float(value), do: {:ok, value}
  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> {:ok, float}
      :error -> {:error, :invalid}
    end
  end
  defp parse_float(_), do: {:error, :invalid}

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
