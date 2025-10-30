defmodule HotspotApi.Storage.Appwrite do
  @moduledoc """
  Appwrite Storage service for handling file uploads.
  """

  @bucket_id "incident-photos"
  @max_file_size 5_242_880 # 5MB in bytes
  @allowed_mime_types ["image/jpeg", "image/png"]

  @doc """
  Upload a file to Appwrite Storage.

  ## Parameters
    - file_binary: The file content as binary
    - filename: Original filename
    - content_type: MIME type of the file

  ## Returns
    - {:ok, file_id} on success
    - {:error, reason} on failure
  """
  def upload_file(file_binary, filename, content_type) do
    with :ok <- validate_file_size(file_binary),
         :ok <- validate_content_type(content_type),
         {:ok, file_id} <- create_file(file_binary, filename, content_type) do
      {:ok, file_id}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get the public URL for a file.
  """
  def get_file_url(file_id) do
    endpoint = appwrite_endpoint()
    project_id = appwrite_project_id()

    "#{endpoint}/storage/buckets/#{@bucket_id}/files/#{file_id}/view?project=#{project_id}"
  end

  @doc """
  Delete a file from Appwrite Storage.
  """
  def delete_file(file_id) do
    url = "#{appwrite_endpoint()}/storage/buckets/#{@bucket_id}/files/#{file_id}"
    headers = appwrite_headers()

    case HTTPoison.delete(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 204}} ->
        :ok
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, "Failed to delete file: #{status_code} - #{body}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  # Private functions

  defp validate_file_size(file_binary) do
    if byte_size(file_binary) <= @max_file_size do
      :ok
    else
      {:error, "File size exceeds 5MB limit"}
    end
  end

  defp validate_content_type(content_type) do
    if content_type in @allowed_mime_types do
      :ok
    else
      {:error, "Invalid file type. Only JPEG and PNG images are allowed"}
    end
  end

  defp create_file(file_binary, filename, content_type) do
    file_id = generate_file_id()
    url = "#{appwrite_endpoint()}/storage/buckets/#{@bucket_id}/files"
    headers = appwrite_headers()

    # Create multipart form data
    multipart = [
      {"fileId", file_id},
      {"file", file_binary, {"form-data", [{"name", "file"}, {"filename", filename}]}, [{"content-type", content_type}]}
    ]

    case HTTPoison.post(url, {:multipart, multipart}, headers) do
      {:ok, %HTTPoison.Response{status_code: 201, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"$id" => id}} -> {:ok, id}
          _ -> {:error, "Failed to parse response"}
        end
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, "Upload failed: #{status_code} - #{body}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  defp generate_file_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp appwrite_endpoint do
    Application.get_env(:hotspot_api, :appwrite_endpoint, "https://cloud.appwrite.io/v1")
  end

  defp appwrite_project_id do
    Application.get_env(:hotspot_api, :appwrite_project_id)
  end

  defp appwrite_api_key do
    Application.get_env(:hotspot_api, :appwrite_api_key)
  end

  defp appwrite_headers do
    [
      {"X-Appwrite-Project", appwrite_project_id()},
      {"X-Appwrite-Key", appwrite_api_key()},
      {"Content-Type", "multipart/form-data"}
    ]
  end
end
