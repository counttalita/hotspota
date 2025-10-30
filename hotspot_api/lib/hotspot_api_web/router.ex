defmodule HotspotApiWeb.Router do
  use HotspotApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug HotspotApiWeb.Plugs.SecurityPipeline
  end

  pipeline :auth do
    plug HotspotApiWeb.Auth.Pipeline
  end

  pipeline :rate_limit_incident do
    plug HotspotApiWeb.Plugs.RateLimiter
  end

  pipeline :validate_image do
    plug HotspotApiWeb.Plugs.ImageValidator
  end

  scope "/api", HotspotApiWeb do
    pipe_through :api

    # Public auth endpoints
    post "/auth/send-otp", AuthController, :send_otp
    post "/auth/verify-otp", AuthController, :verify_otp
  end

  scope "/api", HotspotApiWeb do
    pipe_through [:api, :auth]

    # Protected endpoints
    get "/auth/me", AuthController, :me

    # Incident endpoints (without rate limiting for photo upload)
    post "/incidents/upload-photo", IncidentsController, :upload_photo
    get "/incidents/nearby", IncidentsController, :nearby
    get "/incidents/feed", IncidentsController, :feed

    # Notification endpoints
    post "/notifications/register-token", NotificationsController, :register_token
    get "/notifications/preferences", NotificationsController, :get_preferences
    put "/notifications/preferences", NotificationsController, :update_preferences
  end

  scope "/api", HotspotApiWeb do
    pipe_through [:api, :auth, :rate_limit_incident]

    # Rate-limited incident creation
    post "/incidents", IncidentsController, :create
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:hotspot_api, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: HotspotApiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
