defmodule HotspotApiWeb.Admin.ModerationController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Moderation

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  Lists flagged content for admin review.
  Supports filtering by status, content_type, and user_id.
  """
  def flagged_content(conn, params) do
    filters = %{}
    |> maybe_add_filter(:status, params["status"])
    |> maybe_add_filter(:content_type, params["content_type"])
    |> maybe_add_filter(:user_id, params["user_id"])

    flagged_items = Moderation.list_flagged_content(filters)

    json(conn, %{
      data: Enum.map(flagged_items, &serialize_flagged_content/1),
      total: length(flagged_items)
    })
  end

  @doc """
  Gets a single flagged content item with details.
  """
  def show_flagged_content(conn, %{"id" => id}) do
    flagged = Moderation.get_flagged_content!(id)

    json(conn, %{data: serialize_flagged_content(flagged)})
  end

  @doc """
  Updates flagged content status (approve/reject).
  """
  def update_flagged_content(conn, %{"id" => id, "status" => status}) do
    flagged = Moderation.get_flagged_content!(id)
    admin_id = case conn.assigns[:current_admin] do
      nil -> nil
      admin -> admin.id
    end

    attrs = %{
      status: status,
      reviewed_by: admin_id,
      reviewed_at: DateTime.utc_now()
    }

    case Moderation.update_flagged_content(flagged, attrs) do
      {:ok, updated} ->
        json(conn, %{
          data: serialize_flagged_content(updated),
          message: "Flagged content updated successfully"
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp serialize_flagged_content(flagged) do
    %{
      id: flagged.id,
      content_type: flagged.content_type,
      flag_reason: flagged.flag_reason,
      moderation_score: flagged.moderation_score,
      status: flagged.status,
      reviewed_by: flagged.reviewed_by,
      reviewed_at: flagged.reviewed_at,
      created_at: flagged.inserted_at,
      user: serialize_user(flagged.user),
      incident: serialize_incident(flagged.incident)
    }
  end

  defp serialize_user(nil), do: nil
  defp serialize_user(user) do
    %{
      id: user.id,
      phone_number: user.phone_number
    }
  end

  defp serialize_incident(nil), do: nil
  defp serialize_incident(incident) do
    %{
      id: incident.id,
      type: incident.type,
      description: incident.description
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
