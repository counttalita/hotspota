defmodule HotspotApiWeb.IncidentsJSON do
  alias HotspotApi.Incidents.Incident

  @doc """
  Renders a list of incidents.
  """
  def index(%{incidents: incidents}) do
    %{data: for(incident <- incidents, do: data(incident))}
  end

  @doc """
  Renders a single incident.
  """
  def show(%{incident: incident}) do
    %{data: data(incident)}
  end

  defp data(%Incident{} = incident) do
    %{
      id: incident.id,
      type: incident.type,
      description: incident.description,
      photo_url: incident.photo_url,
      verification_count: incident.verification_count,
      is_verified: incident.is_verified,
      location: format_location(incident.location),
      distance: Map.get(incident, :distance),
      expires_at: incident.expires_at,
      inserted_at: incident.inserted_at,
      updated_at: incident.updated_at
    }
  end

  defp format_location(%Geo.Point{coordinates: {lng, lat}}) do
    %{
      latitude: lat,
      longitude: lng
    }
  end

  defp format_location(_), do: nil
end
