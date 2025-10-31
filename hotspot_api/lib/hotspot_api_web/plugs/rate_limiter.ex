defmodule HotspotApiWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug to protect API endpoints from abuse.

  Uses Hammer library for distributed rate limiting with ETS backend.
  For production with multiple nodes, configure Redis backend.

  ## Usage

      # In router.ex
      pipeline :admin_api do
        plug :accepts, ["json"]
        plug HotspotApiWeb.Plugs.RateLimiter, limit: 100, window_ms: 60_000
      end

  ## Options

    * `:limit` - Maximum number of requests allowed (default: 100)
    * `:window_ms` - Time window in milliseconds (default: 60_000 = 1 minute)
    * `:identifier` - Function to identify the requester (default: uses IP or user ID)

  """
  import Plug.Conn
  import Phoenix.Controller
  require Logger

  def init(opts) do
    %{
      limit: Keyword.get(opts, :limit, 100),
      window_ms: Keyword.get(opts, :window_ms, 60_000),
      identifier_fn: Keyword.get(opts, :identifier, &default_identifier/1)
    }
  end

  def call(conn, opts) do
    # Skip rate limiting in test environment
    if Mix.env() == :test do
      conn
    else
      identifier = opts.identifier_fn.(conn)
      key = "rate_limit:#{identifier}"

      case Hammer.check_rate(key, opts.window_ms, opts.limit) do
        {:allow, count} ->
          conn
          |> put_resp_header("x-ratelimit-limit", to_string(opts.limit))
          |> put_resp_header("x-ratelimit-remaining", to_string(opts.limit - count))
          |> put_resp_header("x-ratelimit-reset", to_string(get_reset_time(opts.window_ms)))

        {:deny, _limit} ->
          Logger.warning("Rate limit exceeded for #{identifier}")

          conn
          |> put_status(:too_many_requests)
          |> put_resp_header("retry-after", to_string(div(opts.window_ms, 1000)))
          |> json(%{
            error: "Rate limit exceeded",
            message: "Too many requests. Please try again later.",
            retry_after_seconds: div(opts.window_ms, 1000)
          })
          |> halt()
      end
    end
  end

  # Default identifier: use authenticated user ID or IP address
  defp default_identifier(conn) do
    case Guardian.Plug.current_resource(conn) do
      nil -> "ip:#{get_ip_address(conn)}"
      %{id: user_id} -> "user:#{user_id}"
    end
  end

  defp get_ip_address(conn) do
    # Handle X-Forwarded-For header for proxies (Render, Fly.io, etc.)
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] ->
        # Take first IP in the chain
        ip |> String.split(",") |> List.first() |> String.trim()
      [] ->
        # Fallback to remote_ip
        conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end

  defp get_reset_time(window_ms) do
    # Calculate when the rate limit window resets
    System.system_time(:second) + div(window_ms, 1000)
  end
end
