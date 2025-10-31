import Config

# Configures Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Req

# Disable Swoosh Local Memory Storage
config :swoosh, local: false

# Do not print debug messages in production
config :logger, level: :info

# Configure structured logging for production
config :logger, :default_formatter,
  format: {Jason, :encode!},
  metadata: [:request_id, :user_id, :ip_address, :method, :path, :status, :duration_ms]

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
