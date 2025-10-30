defmodule HotspotApiWeb.Plugs.ImageValidator do
  @moduledoc """
  Validates uploaded images for size and type.
  """
  import Plug.Conn
  import Phoenix.Controller

  @max_file_size 5_242_880 # 5MB in bytes
  @allowed_mime_types ["image/jpeg", "image/png"]

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.params do
      %{"photo" => %Plug.Upload{} = upload} ->
        validate_upload(conn, upload)
      _ ->
        conn
    end
  end

  defp validate_upload(conn, upload) do
    with :ok <- validate_file_size(upload),
         :ok <- validate_mime_type(upload) do
      conn
    else
      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> put_view(json: HotspotApiWeb.ErrorJSON)
        |> render(:"400", message: message)
        |> halt()
    end
  end

  defp validate_file_size(%Plug.Upload{path: path}) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size}} when size <= @max_file_size ->
        :ok
      {:ok, %File.Stat{size: size}} ->
        {:error, "File size (#{format_bytes(size)}) exceeds maximum allowed size of 5MB"}
      {:error, _} ->
        {:error, "Unable to read file"}
    end
  end

  defp validate_mime_type(%Plug.Upload{content_type: content_type}) do
    if content_type in @allowed_mime_types do
      :ok
    else
      {:error, "Invalid file type '#{content_type}'. Only JPEG and PNG images are allowed"}
    end
  end

  defp format_bytes(bytes) do
    cond do
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)}MB"
      bytes >= 1_024 -> "#{Float.round(bytes / 1_024, 2)}KB"
      true -> "#{bytes}B"
    end
  end
end
