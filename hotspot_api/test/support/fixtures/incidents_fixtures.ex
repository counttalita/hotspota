defmodule HotspotApi.IncidentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `HotspotApi.Incidents` context.
  """

  import HotspotApi.AccountsFixtures

  @doc """
  Generate a incident.
  """
  def incident_fixture(attrs \\ %{}) do
    user = attrs[:user] || user_fixture()

    {:ok, incident} =
      attrs
      |> Enum.into(%{
        description: "Test incident description",
        expires_at: DateTime.add(DateTime.utc_now(), 48, :hour),
        is_verified: false,
        photo_url: nil,
        type: "hijacking",
        verification_count: 0,
        latitude: -26.2041,
        longitude: 28.0473,
        user_id: user.id
      })
      |> HotspotApi.Incidents.create_incident()

    incident
  end
end
