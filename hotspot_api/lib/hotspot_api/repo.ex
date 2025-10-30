defmodule HotspotApi.Repo do
  use Ecto.Repo,
    otp_app: :hotspot_api,
    adapter: Ecto.Adapters.Postgres

  # Configure PostGIS types
  def init(_type, config) do
    {:ok, Keyword.put(config, :types, HotspotApi.PostgresTypes)}
  end
end
