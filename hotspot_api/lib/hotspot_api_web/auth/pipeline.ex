defmodule HotspotApiWeb.Auth.Pipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :hotspot_api,
    module: HotspotApi.Guardian,
    error_handler: HotspotApiWeb.Auth.ErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end
