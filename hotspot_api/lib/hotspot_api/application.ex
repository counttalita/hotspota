defmodule HotspotApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HotspotApiWeb.Telemetry,
      HotspotApi.Repo,
      {DNSCluster, query: Application.get_env(:hotspot_api, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: HotspotApi.PubSub},
      # Start cache for performance optimization
      HotspotApi.Cache,
      # Start Oban for background jobs
      {Oban, Application.fetch_env!(:hotspot_api, Oban)},
      # Start a worker by calling: HotspotApi.Worker.start_link(arg)
      # {HotspotApi.Worker, arg},
      # Start to serve requests, typically the last entry
      HotspotApiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HotspotApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HotspotApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
