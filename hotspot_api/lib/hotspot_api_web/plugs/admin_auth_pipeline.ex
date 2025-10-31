defmodule HotspotApiWeb.Plugs.AdminAuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :hotspot_api,
    module: HotspotApi.Guardian,
    error_handler: HotspotApiWeb.Plugs.AdminAuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
  plug HotspotApiWeb.Plugs.EnsureAdmin
end
