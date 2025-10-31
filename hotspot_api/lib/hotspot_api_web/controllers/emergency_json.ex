defmodule HotspotApiWeb.EmergencyJSON do
  @doc """
  Renders a list of emergency contacts.
  """
  def index(%{contacts: contacts}) do
    %{data: for(contact <- contacts, do: data(contact))}
  end

  @doc """
  Renders a single emergency contact.
  """
  def show(%{contact: contact}) do
    %{data: data(contact)}
  end

  @doc """
  Renders a panic event.
  """
  def panic_event(%{panic_event: panic_event}) do
    %{
      data: %{
        id: panic_event.id,
        latitude: panic_event.latitude,
        longitude: panic_event.longitude,
        status: panic_event.status,
        created_at: panic_event.inserted_at,
        resolved_at: panic_event.resolved_at,
        notes: panic_event.notes
      }
    }
  end

  defp data(contact) do
    %{
      id: contact.id,
      name: contact.name,
      phone_number: contact.phone_number,
      relationship: contact.relationship,
      priority: contact.priority,
      created_at: contact.inserted_at,
      updated_at: contact.updated_at
    }
  end
end
