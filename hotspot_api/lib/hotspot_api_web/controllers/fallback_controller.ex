defmodule HotspotApiWeb.FallbackController do
  use HotspotApiWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{
      error: %{
        code: "not_found",
        message: "Resource not found",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    })
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{
      error: %{
        code: "unauthorized",
        message: "Unauthorized access",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    })
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: %{
        code: "validation_error",
        message: "Validation failed",
        details: translate_errors(changeset),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    })
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
