defmodule HotspotApiWeb.HealthController do
  use HotspotApiWeb, :controller

  @moduledoc """
  Health check endpoint for monitoring and load balancers.
  """

  def index(conn, _params) do
    # Check database connectivity
    db_status = check_database()

    # Check overall health
    status = if db_status == :ok, do: "healthy", else: "unhealthy"
    http_status = if db_status == :ok, do: 200, else: 503

    conn
    |> put_status(http_status)
    |> json(%{
      status: status,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      version: Application.spec(:hotspot_api, :vsn) |> to_string(),
      database: db_status,
      uptime: System.monotonic_time(:second)
    })
  end

  defp check_database do
    try do
      case Ecto.Adapters.SQL.query(HotspotApi.Repo, "SELECT 1", []) do
        {:ok, _} -> :ok
        {:error, _} -> :error
      end
    rescue
      _ -> :error
    end
  end
end
