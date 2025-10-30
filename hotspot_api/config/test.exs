import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :hotspot_api, HotspotApi.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "hotspot_api_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :hotspot_api, HotspotApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "mvbk8/K3Xf1whMZpCUCuFCnBjuUIArXgDGuLyOP7rrR2Qa0Hm7mVRIAR+9/rqRdY",
  server: false

# In test we don't send emails
config :hotspot_api, HotspotApi.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Guardian configuration for tests
config :hotspot_api, HotspotApi.Guardian,
  issuer: "hotspot_api",
  secret_key: "test_secret_key_for_guardian_jwt_tokens_in_test_environment"

# Twilio configuration (disabled in test)
config :hotspot_api,
  twilio_account_sid: nil,
  twilio_auth_token: nil,
  twilio_phone_number: nil


# Disable Oban in test environment
config :hotspot_api, Oban, testing: :manual
