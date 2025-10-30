defmodule HotspotApi.Moderation do
  @moduledoc """
  The Moderation context handles content validation, filtering, and security.
  """

  import Ecto.Query, warn: false
  alias HotspotApi.Repo
  alias HotspotApi.Moderation.{FlaggedContent, ImageHash, TextFilter}
  alias HotspotApi.Security

  @max_image_size 10_485_760  # 10MB in bytes
  @allowed_image_types ["image/jpeg", "image/jpg", "image/png", "image/webp"]

  ## Image Validation

  @doc """
  Validates an image file before upload.
  Checks file type, size, and generates perceptual hash for duplicate detection.
  """
  def validate_image(file_path, content_type) do
    with :ok <- validate_file_type(content_type),
         :ok <- validate_file_size(file_path),
         {:ok, hash} <- generate_image_hash(file_path),
         :ok <- check_duplicate_hash(hash) do
      {:ok, hash}
    end
  end

  defp validate_file_type(content_type) do
    if content_type in @allowed_image_types do
      :ok
    else
      {:error, :invalid_file_type, "Only JPEG, PNG, and WebP images are allowed"}
    end
  end

  defp validate_file_size(file_path) do
    case File.stat(file_path) do
      {:ok, %{size: size}} when size <= @max_image_size ->
        :ok
      {:ok, %{size: size}} ->
        {:error, :file_too_large, "Image must be under 10MB (current: #{Float.round(size / 1_048_576, 2)}MB)"}
      {:error, reason} ->
        {:error, :file_error, "Could not read file: #{inspect(reason)}"}
    end
  end

  @doc """
  Generates a perceptual hash for an image to detect duplicates.
  Uses a simple MD5 hash for now - can be upgraded to pHash later.
  """
  def generate_image_hash(file_path) do
    case File.read(file_path) do
      {:ok, binary} ->
        hash = :crypto.hash(:md5, binary) |> Base.encode16(case: :lower)
        {:ok, hash}
      {:error, reason} ->
        {:error, :hash_generation_failed, "Could not generate hash: #{inspect(reason)}"}
    end
  end

  defp check_duplicate_hash(hash) do
    case get_image_hash_by_hash(hash) do
      nil -> :ok
      _existing -> {:error, :duplicate_image, "This image has already been uploaded"}
    end
  end

  @doc """
  Stores an image hash after successful upload.
  """
  def create_image_hash(attrs \\ %{}) do
    %ImageHash{}
    |> ImageHash.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets an image hash by its hash value.
  """
  def get_image_hash_by_hash(hash) do
    Repo.get_by(ImageHash, hash: hash)
  end

  ## Text Validation

  @doc """
  Validates and sanitizes text content.
  Checks length, filters profanity, and escapes HTML.
  """
  def validate_text(text, opts \\ []) do
    min_length = Keyword.get(opts, :min_length, 10)
    max_length = Keyword.get(opts, :max_length, 500)

    with :ok <- validate_text_length(text, min_length, max_length),
         {:ok, filtered_text} <- TextFilter.filter_profanity(text),
         {:ok, safe_text} <- TextFilter.escape_html(filtered_text) do
      {:ok, safe_text}
    end
  end

  defp validate_text_length(text, min_length, max_length) do
    length = String.length(text)
    cond do
      length < min_length ->
        {:error, :text_too_short, "Description must be at least #{min_length} characters"}
      length > max_length ->
        {:error, :text_too_long, "Description must be at most #{max_length} characters"}
      true ->
        :ok
    end
  end

  ## Flagged Content

  @doc """
  Creates a flagged content record.
  """
  def create_flagged_content(attrs \\ %{}) do
    %FlaggedContent{}
    |> FlaggedContent.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, flagged} = result ->
        # Log security event
        Security.log_event(%{
          event_type: "content_flagged",
          user_id: flagged.user_id,
          details: %{
            content_type: flagged.content_type,
            flag_reason: flagged.flag_reason,
            incident_id: flagged.incident_id
          },
          severity: "medium"
        })
        result
      error -> error
    end
  end

  @doc """
  Lists flagged content with optional filters.
  """
  def list_flagged_content(filters \\ %{}) do
    FlaggedContent
    |> apply_flagged_content_filters(filters)
    |> Repo.all()
    |> Repo.preload([:user, :incident])
  end

  defp apply_flagged_content_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:status, status}, query ->
        where(query, [f], f.status == ^status)
      {:content_type, type}, query ->
        where(query, [f], f.content_type == ^type)
      {:user_id, user_id}, query ->
        where(query, [f], f.user_id == ^user_id)
      _, query ->
        query
    end)
  end

  @doc """
  Gets a single flagged content record.
  """
  def get_flagged_content!(id) do
    Repo.get!(FlaggedContent, id)
    |> Repo.preload([:user, :incident])
  end

  @doc """
  Updates flagged content status.
  """
  def update_flagged_content(%FlaggedContent{} = flagged, attrs) do
    flagged
    |> FlaggedContent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Flags a user for repeat offenses.
  Checks if user has multiple flagged content items.
  """
  def check_repeat_offender(user_id) do
    count = Repo.one(
      from f in FlaggedContent,
      where: f.user_id == ^user_id and f.status == "rejected",
      select: count(f.id)
    )

    if count >= 3 do
      Security.log_event(%{
        event_type: "repeat_offender_detected",
        user_id: user_id,
        details: %{flagged_content_count: count},
        severity: "high"
      })
      {:warning, :repeat_offender, count}
    else
      {:ok, count}
    end
  end
end
