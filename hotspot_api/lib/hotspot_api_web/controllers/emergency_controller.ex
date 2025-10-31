defmodule HotspotApiWeb.EmergencyController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Accounts
  alias HotspotApi.Guardian

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  Lists all emergency contacts for the authenticated user.
  GET /api/emergency-contacts
  """
  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    contacts = Accounts.list_emergency_contacts(user.id)
    render(conn, :index, contacts: contacts)
  end

  @doc """
  Creates a new emergency contact for the authenticated user.
  POST /api/emergency-contacts
  """
  def create(conn, %{"emergency_contact" => contact_params}) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.create_emergency_contact(user.id, contact_params) do
      {:ok, contact} ->
        conn
        |> put_status(:created)
        |> render(:show, contact: contact)

      {:error, :max_contacts_reached} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Maximum 5 emergency contacts allowed"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(HotspotApiWeb.ChangesetJSON, :error, changeset: changeset)
    end
  end

  @doc """
  Updates an emergency contact.
  PUT /api/emergency-contacts/:id
  """
  def update(conn, %{"id" => id, "emergency_contact" => contact_params}) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.get_user_emergency_contact(user.id, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Emergency contact not found"})

      contact ->
        case Accounts.update_emergency_contact(contact, contact_params) do
          {:ok, updated_contact} ->
            render(conn, :show, contact: updated_contact)

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render(HotspotApiWeb.ChangesetJSON, :error, changeset: changeset)
        end
    end
  end

  @doc """
  Deletes an emergency contact.
  DELETE /api/emergency-contacts/:id
  """
  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.get_user_emergency_contact(user.id, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Emergency contact not found"})

      contact ->
        case Accounts.delete_emergency_contact(contact) do
          {:ok, _contact} ->
            send_resp(conn, :no_content, "")

          {:error, _changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to delete emergency contact"})
        end
    end
  end

  @doc """
  Triggers the panic button - creates panic event and sends alerts.
  POST /api/emergency/panic
  """
  def trigger_panic(conn, %{"latitude" => lat, "longitude" => lng}) do
    user = Guardian.Plug.current_resource(conn)

    # Check if user already has an active panic event
    case Accounts.get_active_panic_event(user.id) do
      nil ->
        case Accounts.trigger_panic_button(user.id, lat, lng) do
          {:ok, panic_event} ->
            conn
            |> put_status(:created)
            |> render(:panic_event, panic_event: panic_event)

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render(HotspotApiWeb.ChangesetJSON, :error, changeset: changeset)
        end

      _active_event ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "You already have an active panic alert"})
    end
  end

  @doc """
  Gets the current panic status for the user.
  GET /api/emergency/panic/status
  """
  def get_panic_status(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.get_active_panic_event(user.id) do
      nil ->
        json(conn, %{active: false, panic_event: nil})

      panic_event ->
        json(conn, %{active: true, panic_event: format_panic_event(panic_event)})
    end
  end

  @doc """
  Resolves/cancels the active panic event.
  POST /api/emergency/panic/resolve
  """
  def resolve_panic(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.get_active_panic_event(user.id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No active panic event found"})

      panic_event ->
        notes = Map.get(params, "notes")

        case Accounts.resolve_panic_event(panic_event.id, notes) do
          {:ok, resolved_event} ->
            render(conn, :panic_event, panic_event: resolved_event)

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render(HotspotApiWeb.ChangesetJSON, :error, changeset: changeset)
        end
    end
  end

  # Helper function to format panic event for JSON response
  defp format_panic_event(panic_event) do
    %{
      id: panic_event.id,
      latitude: panic_event.latitude,
      longitude: panic_event.longitude,
      status: panic_event.status,
      created_at: panic_event.inserted_at,
      resolved_at: panic_event.resolved_at,
      notes: panic_event.notes
    }
  end
end
