defmodule HotspotApiWeb.ModerationController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Moderation
  alias HotspotApi.Security

  action_fallback(HotspotApiWeb.FallbackController)

  @doc """
  Validates an image before upload.
  Checks file type, size, and generates hash for duplicate detection.
  """
  def validate_image(conn, %{"file" => file}) do
    content_type = file.content_type

    case Moderation.validate_image(file.path, content_type) do
      {:ok, hash} ->
        json(conn, %{
          valid: true,
          hash: hash,
          message: "Image is valid and ready for upload"
        })

      {:error, :invalid_file_type, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{valid: false, error: "invalid_file_type", message: message})

      {:error, :file_too_large, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{valid: false, error: "file_too_large", message: message})

      {:error, :duplicate_image, message} ->
        conn
        |> put_status(:conflict)
        |> json(%{valid: false, error: "duplicate_image", message: message})

      {:error, reason, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{valid: false, error: to_string(reason), message: message})
    end
  end

  def validate_image(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing file parameter"})
  end

  @doc """
  Validates and sanitizes text content.
  Filters profanity, detects hate speech, and escapes HTML.
  """
  def validate_text(conn, %{"text" => text}) do
    min_length = Map.get(conn.params, "min_length", 10) |> parse_integer(10)
    max_length = Map.get(conn.params, "max_length", 500) |> parse_integer(500)

    case Moderation.validate_text(text, min_length: min_length, max_length: max_length) do
      {:ok, sanitized_text} ->
        json(conn, %{
          valid: true,
          sanitized_text: sanitized_text,
          contains_profanity: Moderation.TextFilter.contains_profanity?(text),
          message: "Text is valid"
        })

      {:error, :text_too_short, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{valid: false, error: "text_too_short", message: message})

      {:error, :text_too_long, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{valid: false, error: "text_too_long", message: message})

      {:error, :hate_speech_detected, message} ->
        # Log security event
        user_id =
          case conn.assigns[:current_user] do
            nil -> nil
            user -> user.id
          end

        ip_address = Security.get_ip_address(conn)

        Security.log_event(%{
          event_type: "hate_speech_detected",
          user_id: user_id,
          ip_address: ip_address,
          details: %{text: text},
          severity: "high"
        })

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{valid: false, error: "hate_speech_detected", message: message})

      {:error, reason, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{valid: false, error: to_string(reason), message: message})
    end
  end

  def validate_text(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing text parameter"})
  end

  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_integer(value, _default) when is_integer(value), do: value
  defp parse_integer(_, default), do: default
end
