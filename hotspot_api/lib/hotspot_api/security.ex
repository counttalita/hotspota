defmodule HotspotApi.Security do
  @moduledoc """
  The Security context - handles cybersecurity, attack prevention, and intrusion detection.
  """

  import Ecto.Query, warn: false
  alias HotspotApi.Repo
  alias HotspotApi.Security.{IPBlocklist, AuthAttempt, IntrusionAlert, SecurityEvent}

  ## IP Blocklist

  @doc """
  Checks if an IP address is blocked.
  """
  def ip_blocked?(ip_address) when is_binary(ip_address) do
    query =
      from b in IPBlocklist,
        where: b.ip_address == ^ip_address,
        where: b.is_permanent == true or b.expires_at > ^DateTime.utc_now()

    Repo.exists?(query)
  end

  @doc """
  Blocks an IP address for a specified duration or permanently.
  """
  def block_ip(ip_address, reason, opts \\ []) do
    duration_seconds = Keyword.get(opts, :duration_seconds, 3600)
    is_permanent = Keyword.get(opts, :permanent, false)

    expires_at =
      if is_permanent do
        nil
      else
        DateTime.utc_now() |> DateTime.add(duration_seconds, :second)
      end

    %IPBlocklist{}
    |> IPBlocklist.changeset(%{
      ip_address: ip_address,
      reason: reason,
      expires_at: expires_at,
      is_permanent: is_permanent
    })
    |> Repo.insert(
      on_conflict: {:replace, [:reason, :expires_at, :is_permanent, :blocked_at]},
      conflict_target: :ip_address
    )
  end

  @doc """
  Unblocks an IP address.
  """
  def unblock_ip(ip_address) do
    from(b in IPBlocklist, where: b.ip_address == ^ip_address)
    |> Repo.delete_all()
  end

  ## Authentication Attempts

  @doc """
  Records an authentication attempt.
  """
  def record_auth_attempt(attrs) do
    %AuthAttempt{}
    |> AuthAttempt.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Checks if phone number has exceeded login attempts.
  Returns {:ok, :allowed} or {:error, :too_many_attempts, retry_after_seconds}.
  """
  def check_login_rate_limit(phone_number) do
    fifteen_minutes_ago = DateTime.utc_now() |> DateTime.add(-15, :minute)

    failed_attempts =
      from(a in AuthAttempt,
        where: a.phone_number == ^phone_number,
        where: a.success == false,
        where: a.created_at > ^fifteen_minutes_ago
      )
      |> Repo.aggregate(:count)

    if failed_attempts >= 5 do
      {:error, :too_many_attempts, 900}
    else
      {:ok, :allowed}
    end
  end

  @doc """
  Gets recent failed login attempts for an IP address.
  """
  def get_failed_attempts_by_ip(ip_address, minutes_ago \\ 60) do
    time_ago = DateTime.utc_now() |> DateTime.add(-minutes_ago, :minute)

    from(a in AuthAttempt,
      where: a.ip_address == ^ip_address,
      where: a.success == false,
      where: a.created_at > ^time_ago,
      order_by: [desc: a.created_at]
    )
    |> Repo.all()
  end

  ## Intrusion Detection

  @doc """
  Creates an intrusion alert.
  """
  def create_intrusion_alert(attrs) do
    %IntrusionAlert{}
    |> IntrusionAlert.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Detects SQL injection patterns in input.
  """
  def detect_sql_injection?(input) when is_binary(input) do
    sql_patterns = [
      ~r/(\bOR\b|\bAND\b).*=.*\d+/i,
      ~r/UNION.*SELECT/i,
      ~r/DROP\s+TABLE/i,
      ~r/DELETE\s+FROM/i,
      ~r/INSERT\s+INTO/i,
      ~r/--/,
      ~r/;.*--/,
      ~r/\/\*.*\*\//
    ]

    Enum.any?(sql_patterns, &Regex.match?(&1, input))
  end

  def detect_sql_injection?(_), do: false

  @doc """
  Detects XSS attack patterns in input.
  """
  def detect_xss?(input) when is_binary(input) do
    xss_patterns = [
      ~r/<script/i,
      ~r/<iframe/i,
      ~r/javascript:/i,
      ~r/onerror=/i,
      ~r/onload=/i,
      ~r/onclick=/i,
      ~r/<img.*src=/i
    ]

    Enum.any?(xss_patterns, &Regex.match?(&1, input))
  end

  def detect_xss?(_), do: false

  @doc """
  Detects path traversal attack patterns.
  """
  def detect_path_traversal?(input) when is_binary(input) do
    path_patterns = [
      ~r/\.\.\//,
      ~r/\.\.%2F/i,
      ~r/%2e%2e/i,
      ~r/etc\/passwd/i,
      ~r/windows\/system/i
    ]

    Enum.any?(path_patterns, &Regex.match?(&1, input))
  end

  def detect_path_traversal?(_), do: false

  @doc """
  Analyzes request for suspicious patterns and creates alerts.
  """
  def analyze_request(conn, user_id \\ nil) do
    ip_address = get_ip_address(conn)
    params_string = inspect(conn.params)

    cond do
      detect_sql_injection?(params_string) ->
        create_alert_and_block(conn, ip_address, "sql_injection", "high", user_id)

      detect_xss?(params_string) ->
        create_alert_and_block(conn, ip_address, "xss_attempt", "high", user_id)

      detect_path_traversal?(params_string) ->
        create_alert_and_block(conn, ip_address, "path_traversal", "medium", user_id)

      true ->
        :ok
    end
  end

  defp create_alert_and_block(conn, ip_address, attack_type, severity, _user_id) do
    # Create intrusion alert
    create_intrusion_alert(%{
      ip_address: ip_address,
      attack_type: attack_type,
      request_path: conn.request_path,
      request_params: conn.params,
      severity: severity,
      auto_blocked: true
    })

    # Block IP for 1 hour
    block_ip(ip_address, "Automatic block: #{attack_type}", duration_seconds: 3600)

    {:blocked, attack_type}
  end

  @doc """
  Gets IP address from connection, handling proxies.
  """
  def get_ip_address(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> to_string(:inet.ntoa(conn.remote_ip))
    end
  end

  @doc """
  Sanitizes HTML to prevent XSS attacks.
  """
  def sanitize_html(text) when is_binary(text) do
    text
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  def sanitize_html(nil), do: nil

  ## Security Events

  @doc """
  Logs a security event.
  """
  def log_event(attrs) do
    %SecurityEvent{}
    |> SecurityEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists security events with optional filters.
  """
  def list_security_events(filters \\ %{}) do
    SecurityEvent
    |> apply_security_event_filters(filters)
    |> order_by([e], desc: e.inserted_at)
    |> limit(100)
    |> Repo.all()
  end

  defp apply_security_event_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:event_type, type}, query ->
        where(query, [e], e.event_type == ^type)
      {:severity, severity}, query ->
        where(query, [e], e.severity == ^severity)
      {:user_id, user_id}, query ->
        where(query, [e], e.user_id == ^user_id)
      _, query ->
        query
    end)
  end
end
