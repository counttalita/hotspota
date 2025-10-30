defmodule HotspotApi.Repo do
  use Ecto.Repo,
    otp_app: :hotspot_api,
    adapter: Ecto.Adapters.Postgres
end
