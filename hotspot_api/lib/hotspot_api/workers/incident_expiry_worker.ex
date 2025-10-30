defmodule HotspotApi.Workers.IncidentExpiryWorker do
  @moduledoc """
  Oban worker that runs every hour to delete expired incidents with zero verifications.
  Incidents expire 48 hours after creation if they have not been verified by the community.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias HotspotApi.Incidents

  @impl Oban.Worker
  def perform(_job) do
    case Incidents.delete_expired_incidents() do
      {count, _} when count > 0 ->
        IO.puts("Deleted #{count} expired incidents")
        :ok

      {0, _} ->
        IO.puts("No expired incidents to delete")
        :ok
    end
  end
end
