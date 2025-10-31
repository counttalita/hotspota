defmodule HotspotApiWeb.SyncController do
  use HotspotApiWeb, :controller
  alias HotspotApi.Incidents
  alias HotspotApi.Accounts

  plug :authenticate_user when action in [:sync_reports]

  defp authenticate_user(conn, _opts) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
        |> halt()
      _user ->
        conn
    end
  end

  @doc """
  Sync queued incident reports from offline clients
  Handles idempotency to prevent duplicate submissions
  """
  def sync_reports(conn, %{"reports" => reports}) when is_list(reports) do
    user = Guardian.Plug.current_resource(conn)

    results = Enum.map(reports, fn report ->
      sync_single_report(user, report)
    end)

    {successful, failed} = Enum.split_with(results, fn {status, _} -> status == :ok end)

    json(conn, %{
      synced: length(successful),
      failed: length(failed),
      results: Enum.map(results, fn
        {:ok, incident} -> %{status: "success", id: incident.id, client_id: incident.client_id}
        {:error, reason, client_id} -> %{status: "error", reason: reason, client_id: client_id}
      end)
    })
  end

  def sync_reports(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "reports array is required"})
  end

  defp sync_single_report(user, report) do
    idempotency_key = Map.get(report, "idempotency_key")
    client_id = Map.get(report, "client_id")

    # Check if report already exists using idempotency key
    if idempotency_key && Incidents.get_by_idempotency_key(idempotency_key) do
      {:error, "duplicate_submission", client_id}
    else
      params = prepare_incident_params(report, idempotency_key, user.id)
      case Incidents.create_incident(params) do
        {:ok, incident} ->
          {:ok, Map.put(incident, :client_id, client_id)}
        {:error, changeset} ->
          {:error, format_errors(changeset), client_id}
      end
    end
  end

  defp prepare_incident_params(report, idempotency_key, user_id) do
    %{
      "type" => Map.get(report, "type"),
      "latitude" => Map.get(report, "latitude"),
      "longitude" => Map.get(report, "longitude"),
      "description" => Map.get(report, "description"),
      "photo_url" => Map.get(report, "photo_url"),
      "idempotency_key" => idempotency_key,
      "user_id" => user_id,
      "reported_at" => Map.get(report, "reported_at") || DateTime.utc_now()
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end
end
