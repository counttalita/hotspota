defmodule HotspotApiWeb.Plugs.SecurityPipeline do
  @moduledoc """
  Security middleware that adds security headers, validates CORS, checks rate limits,
  and blocks malicious IPs.
  """

  import Plug.Conn
  alias HotspotApi.Security

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_secure_headers()
    |> validate_origin()
    |> check_ip_blocklist()
    |> check_rate_limit()
    |> analyze_for_attacks()
  end

  # Add security headers to prevent common attacks
  defp put_secure_headers(conn) do
    conn
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
    |> put_resp_header("content-security-policy", "default-src 'self'")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "geolocation=(self), camera=(), microphone=()")
  end

  # Validate CORS origin against whitelist
  defp validate_origin(conn) do
    allowed_origins = get_allowed_origins()
    origin = get_req_header(conn, "origin") |> List.first()

    cond do
      is_nil(origin) ->
        # No origin header (same-origin request or non-browser)
        conn

      origin in allowed_origins ->
        conn
        |> put_resp_header("access-control-allow-origin", origin)
        |> put_resp_header("access-control-allow-credentials", "true")
        |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization, X-CSRF-Token")

      true ->
        conn
        |> send_resp(403, Jason.encode!(%{error: "Origin not allowed"}))
        |> halt()
    end
  end

  # Check if IP is in blocklist
  defp check_ip_blocklist(conn) do
    ip_address = Security.get_ip_address(conn)

    if Security.ip_blocked?(ip_address) do
      conn
      |> send_resp(403, Jason.encode!(%{error: "Access denied"}))
      |> halt()
    else
      conn
    end
  end

  # Rate limit by IP address
  defp check_rate_limit(conn) do
    ip_address = Security.get_ip_address(conn)

    case Hammer.check_rate("api:#{ip_address}", 60_000, 100) do
      {:allow, _count} ->
        conn

      {:deny, limit} ->
        conn
        |> put_resp_header("retry-after", "60")
        |> send_resp(429, Jason.encode!(%{
          error: "Rate limit exceeded",
          limit: limit,
          retry_after: 60
        }))
        |> halt()
    end
  end

  # Analyze request for attack patterns
  defp analyze_for_attacks(conn) do
    case Security.analyze_request(conn) do
      {:blocked, attack_type} ->
        conn
        |> send_resp(403, Jason.encode!(%{
          error: "Suspicious activity detected",
          type: attack_type
        }))
        |> halt()

      :ok ->
        conn
    end
  end

  defp get_allowed_origins do
    [
      "https://hotspot.app",
      "https://www.hotspot.app",
      "https://admin.hotspot.app",
      "http://localhost:3000",
      "http://localhost:5173",
      "http://localhost:8081",  # Expo dev
      "exp://localhost:8081"     # Expo
    ]
  end
end
