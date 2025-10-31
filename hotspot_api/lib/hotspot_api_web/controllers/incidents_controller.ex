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
    # Validate image before upload
    with {:ok, hash} <- HotspotApi.Moderation.validate_image(upload.path, upload.content_type),
         {:ok, file_binary} <- File.read(upload.path),
         {:ok, file_id} <- Appwrite.upload_file(file_binary, upload.filename, upload.content_type) do
      photo_url = Appwrite.get_file_url(file_id)

      conn
      |> put_status(:created)
      |> json(%{
        file_id: file_id,
        photo_url: photo_url,
        hash: hash
      })
    else
      {:error, :invalid_file_type, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})

      {:error, :file_too_large, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})

      {:error, :duplicate_image, message} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: message})

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

    # Validate description if present
    with :ok <- validate_description(incident_params["description"]),
         :ok <- check_repeat_offender(user_id) do
      incident_params = Map.put(incident_params, "user_id", user_id)

      case Incidents.create_incident(incident_params) do
        {:ok, %Incident{} = incident} ->
          # Send notifications to nearby users asynchronously
          Task.start(fn ->
            HotspotApi.Notifications.send_incident_alert(incident.id, incident.location)
          end)

          conn
          |> put_status(:created)
          |> render(:show, incident: incident)

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, :text_validation_failed, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})

      {:error, :repeat_offender, count} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: "Account flagged",
          message: "Your account has been flagged for #{count} violations. Please contact support."
        })
    end
  end

  defp validate_description(nil), do: :ok
  defp validate_description(""), do: :ok
  defp validate_description(description) do
    case HotspotApi.Moderation.validate_text(description, min_length: 10, max_length: 500) do
      {:ok, _sanitized} -> :ok
      {:error, _reason, message} -> {:error, :text_validation_failed, message}
    end
  end

  defp check_repeat_offender(user_id) do
    case HotspotApi.Moderation.check_repeat_offender(user_id) do
      {:ok, _count} -> :ok
      {:warning, :repeat_offender, count} -> {:error, :repeat_offender, count}
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

  @doc """
  Verify an incident (upvote)
  """
  def verify(conn, %{"id" => incident_id}) do
    user_id = Guardian.Plug.current_resource(conn).id

    case Incidents.verify_incident(incident_id, user_id) do
      {:ok, _verification} ->
        # Get updated incident to return current verification count
        incident = Incidents.get_incident!(incident_id)

        conn
        |> put_status(:created)
        |> json(%{
          message: "Incident verified successfully",
          verification_count: incident.verification_count,
          is_verified: incident.is_verified
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: format_error(errors)})
    end
  end

  @doc """
  Get verifications for an incident
  """
  def verifications(conn, %{"id" => incident_id}) do
    verifications = Incidents.get_incident_verifications(incident_id)

    conn
    |> json(%{
      incident_id: incident_id,
      verification_count: length(verifications),
      verifications: Enum.map(verifications, fn v ->
        %{
          id: v.id,
          user_id: v.user_id,
          verified_at: v.inserted_at
        }
      end)
    })
  end

  @doc """
  Get paginated incident feed with filtering
  """
  def feed(conn, params) do
    with {:ok, latitude} <- parse_float(params["lat"], "latitude"),
         {:ok, longitude} <- parse_float(params["lng"], "longitude") do
      radius = parse_radius(params["radius"])

      opts = [
        type: params["type"],
        time_range: params["time_range"] || "all",
        page: parse_page(params["page"]),
        page_size: parse_page_size(params["page_size"])
      ]

      result = Incidents.list_nearby_paginated(latitude, longitude, radius, opts)

      conn
      |> json(%{
        incidents: Enum.map(result.incidents, &format_incident/1),
        pagination: %{
          total_count: result.total_count,
          page: result.page,
          page_size: result.page_size,
          total_pages: result.total_pages
        }
      })
    else
      {:error, field} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid #{field} parameter"})
    end
  end

  @doc """
  Get heatmap data showing incident clusters from the past 7 days.
  Returns cluster centers with incident counts and dominant type.
  Only includes clusters with 5+ incidents.
  """
  def heatmap(conn, _params) do
    heatmap_data = Incidents.get_heatmap_data()

    conn
    |> json(%{
      clusters: heatmap_data,
      generated_at: DateTime.utc_now()
    })
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

  defp parse_page(nil), do: 1
  defp parse_page(page) when is_integer(page), do: max(page, 1)
  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {int, _} -> max(int, 1)
      :error -> 1
    end
  end
  defp parse_page(_), do: 1

  defp parse_page_size(nil), do: 20
  defp parse_page_size(size) when is_integer(size), do: min(max(size, 1), 100)
  defp parse_page_size(size) when is_binary(size) do
    case Integer.parse(size) do
      {int, _} -> min(max(int, 1), 100)
      :error -> 20
    end
  end
  defp parse_page_size(_), do: 20

  defp format_incident(%Incident{location: %Geo.Point{coordinates: {lng, lat}}} = incident) do
    %{
      id: incident.id,
      type: incident.type,
      description: incident.description,
      photo_url: incident.photo_url,
      verification_count: incident.verification_count,
      is_verified: incident.is_verified,
      location: %{
        latitude: lat,
        longitude: lng
      },
      distance: Map.get(incident, :distance),
      inserted_at: incident.inserted_at,
      expires_at: incident.expires_at
    }
  end

  defp format_error(errors) when is_map(errors) do
    errors
    |> Enum.map(fn {field, messages} ->
      "#{field}: #{Enum.join(messages, ", ")}"
    end)
    |> Enum.join("; ")
  end
end
