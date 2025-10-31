defmodule HotspotApi.Workers.ZoneUpdateWorker do
  @moduledoc """
  Oban worker that runs every 10 minutes to update hotspot zones based on incident clustering.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  alias HotspotApi.Geofencing

  @impl Oban.Worker
  def perform(_job) do
    case Geofencing.update_zones() do
      {:ok, stats} ->
        # Log the results
        IO.puts("Zone update completed: #{inspect(stats)}")
        :ok

      {:error, reason} ->
        # Log error and allow Oban to retry
        IO.puts("Zone update failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Schedule the zone update worker to run every 10 minutes.
  This should be called from the application supervisor.
  """
  def schedule do
    # Schedule to run every 10 minutes
    %{}
    |> HotspotApi.Workers.ZoneUpdateWorker.new(schedule: "*/10 * * * *")
    |> Oban.insert()
  end
end
