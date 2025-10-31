defmodule HotspotApiWeb.Router do
  use HotspotApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug HotspotApiWeb.Plugs.RequestLogger
    plug HotspotApiWeb.Plugs.SecurityPipeline
  end

  pipeline :api_v1 do
    plug :api
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

  # API v1 routes
  scope "/api/v1", HotspotApiWeb do
    pipe_through :api_v1

    # Public auth endpoints
    post "/auth/send-otp", AuthController, :send_otp
    post "/auth/verify-otp", AuthController, :verify_otp
  end

  scope "/api/v1", HotspotApiWeb do
    pipe_through [:api_v1, :auth]

    # Protected endpoints
    get "/auth/me", AuthController, :me

    # Incident endpoints (without rate limiting for photo upload)
    post "/incidents/upload-photo", IncidentsController, :upload_photo
    get "/incidents/nearby", IncidentsController, :nearby
    get "/incidents/feed", IncidentsController, :feed
    get "/incidents/heatmap", IncidentsController, :heatmap
    post "/incidents/:id/verify", IncidentsController, :verify
    get "/incidents/:id/verifications", IncidentsController, :verifications

    # Notification endpoints
    post "/notifications/register-token", NotificationsController, :register_token
    get "/notifications/preferences", NotificationsController, :get_preferences
    put "/notifications/preferences", NotificationsController, :update_preferences

    # Moderation endpoints
    post "/moderation/validate-image", ModerationController, :validate_image
    post "/moderation/validate-text", ModerationController, :validate_text
  end

  scope "/api/v1", HotspotApiWeb do
    pipe_through [:api_v1, :auth, :rate_limit_incident]

    # Rate-limited incident creation
    post "/incidents", IncidentsController, :create
  end

  # Legacy API routes (redirect to v1)
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
    post "/incidents/upload-photo", IncidentsController, :upload_photo
    get "/incidents/nearby", IncidentsController, :nearby
    get "/incidents/feed", IncidentsController, :feed
    get "/incidents/heatmap", IncidentsController, :heatmap
    post "/incidents/:id/verify", IncidentsController, :verify
    get "/incidents/:id/verifications", IncidentsController, :verifications
    post "/notifications/register-token", NotificationsController, :register_token
    get "/notifications/preferences", NotificationsController, :get_preferences
    put "/notifications/preferences", NotificationsController, :update_preferences
    post "/moderation/validate-image", ModerationController, :validate_image
    post "/moderation/validate-text", ModerationController, :validate_text
  end

  scope "/api", HotspotApiWeb do
    pipe_through [:api, :auth, :rate_limit_incident]
    post "/incidents", IncidentsController, :create
  end

  # Admin routes (TODO: Add admin authentication pipeline)
  scope "/api/v1/admin", HotspotApiWeb.Admin, as: :admin do
    pipe_through :api_v1

    # Moderation endpoints
    get "/moderation/flagged-content", ModerationController, :flagged_content
    get "/moderation/flagged-content/:id", ModerationController, :show_flagged_content
    put "/moderation/flagged-content/:id", ModerationController, :update_flagged_content
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
