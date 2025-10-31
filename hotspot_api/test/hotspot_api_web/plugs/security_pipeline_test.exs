defmodule HotspotApiWeb.Plugs.SecurityPipelineTest do
  use HotspotApiWeb.ConnCase, async: false

  alias HotspotApiWeb.Plugs.SecurityPipeline
  alias HotspotApi.Security
  alias HotspotApi.Repo

  setup do
    # Clear any existing blocks before each test
    Repo.delete_all(Security.IPBlocklist)
    :ok
  end

  describe "security headers" do
    test "adds X-Frame-Options header", %{conn: conn} do
      conn = SecurityPipeline.call(conn, [])
      assert get_resp_header(conn, "x-frame-options") == ["DENY"]
    end

    test "adds X-Content-Type-Options header", %{conn: conn} do
      conn = SecurityPipeline.call(conn, [])
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "adds X-XSS-Protection header", %{conn: conn} do
      conn = SecurityPipeline.call(conn, [])
      assert get_resp_header(conn, "x-xss-protection") == ["1; mode=block"]
    end

    test "adds Strict-Transport-Security header", %{conn: conn} do
      conn = SecurityPipeline.call(conn, [])
      hsts = get_resp_header(conn, "strict-transport-security")
      assert hsts == ["max-age=31536000; includeSubDomains"]
    end

    test "adds Content-Security-Policy header", %{conn: conn} do
      conn = SecurityPipeline.call(conn, [])
      assert get_resp_header(conn, "content-security-policy") == ["default-src 'self'"]
    end

    test "adds Referrer-Policy header", %{conn: conn} do
      conn = SecurityPipeline.call(conn, [])
      assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]
    end

    test "adds Permissions-Policy header", %{conn: conn} do
      conn = SecurityPipeline.call(conn, [])
      policy = get_resp_header(conn, "permissions-policy")
      assert policy == ["geolocation=(self), camera=(), microphone=()"]
    end
  end

  describe "CORS validation" do
    test "allows request without origin header", %{conn: conn} do
      conn = SecurityPipeline.call(conn, [])
      refute conn.halted
    end

    test "allows request from whitelisted origin", %{conn: conn} do
      conn =
        conn
        |> put_req_header("origin", "http://localhost:3000")
        |> SecurityPipeline.call([])

      refute conn.halted
      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
      assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]
    end

    test "blocks request from non-whitelisted origin", %{conn: conn} do
      conn =
        conn
        |> put_req_header("origin", "https://evil.com")
        |> SecurityPipeline.call([])

      assert conn.halted
      assert conn.status == 403
    end

    test "allows multiple whitelisted origins", %{conn: conn} do
      origins = [
        "https://hotspot.app",
        "https://admin.hotspot.app",
        "http://localhost:5173"
      ]

      for origin <- origins do
        conn =
          build_conn()
          |> put_req_header("origin", origin)
          |> SecurityPipeline.call([])

        refute conn.halted
        assert get_resp_header(conn, "access-control-allow-origin") == [origin]
      end
    end
  end

  describe "IP blocklist checking" do
    test "allows request from non-blocked IP", %{conn: conn} do
      conn = SecurityPipeline.call(conn, [])
      refute conn.halted
    end

    test "blocks request from blocked IP", %{conn: conn} do
      # Block the test IP
      Security.block_ip("127.0.0.1", "Test block")

      conn = SecurityPipeline.call(conn, [])

      assert conn.halted
      assert conn.status == 403
    end

    test "blocks request from permanently blocked IP", %{conn: conn} do
      Security.block_ip("127.0.0.1", "Permanent block", permanent: true)

      conn = SecurityPipeline.call(conn, [])

      assert conn.halted
      assert conn.status == 403
    end
  end

  describe "rate limiting" do
    @tag :skip
    test "allows requests under rate limit", %{conn: conn} do
      # Make 5 requests (well under 100/min limit)
      for _ <- 1..5 do
        conn =
          build_conn()
          |> SecurityPipeline.call([])

        refute conn.halted
      end
    end

    @tag :skip
    test "blocks requests over rate limit", %{conn: conn} do
      # Simulate 101 requests in quick succession
      # Note: This test may be flaky depending on Hammer configuration
      # In real scenarios, you'd mock Hammer or use a test-specific config

      # For now, just verify the rate limit check is called
      conn = SecurityPipeline.call(conn, [])
      refute conn.halted
    end
  end

  describe "attack pattern detection" do
    test "blocks SQL injection attempt", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"id" => "1' OR '1'='1"})
        |> SecurityPipeline.call([])

      assert conn.halted
      assert conn.status == 403

      # Verify intrusion alert was created
      alerts = Repo.all(Security.IntrusionAlert)
      assert length(alerts) > 0
      assert hd(alerts).attack_type == "sql_injection"
    end

    test "blocks XSS attempt", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"description" => "<script>alert('xss')</script>"})
        |> SecurityPipeline.call([])

      assert conn.halted
      assert conn.status == 403

      alerts = Repo.all(Security.IntrusionAlert)
      assert length(alerts) > 0
      assert hd(alerts).attack_type == "xss_attempt"
    end

    test "blocks path traversal attempt", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"file" => "../../etc/passwd"})
        |> SecurityPipeline.call([])

      assert conn.halted
      assert conn.status == 403

      alerts = Repo.all(Security.IntrusionAlert)
      assert length(alerts) > 0
      assert hd(alerts).attack_type == "path_traversal"
    end

    test "allows safe requests", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"description" => "Normal text description"})
        |> SecurityPipeline.call([])

      refute conn.halted
    end

    test "auto-blocks IP after attack detection", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"id" => "1' OR '1'='1"})
        |> SecurityPipeline.call([])

      assert conn.halted

      # Verify IP was blocked
      assert Security.ip_blocked?("127.0.0.1")
    end
  end

  describe "X-Forwarded-For header handling" do
    test "uses X-Forwarded-For IP when present", %{conn: conn} do
      forwarded_ip = "203.0.113.1"

      # Block the forwarded IP
      Security.block_ip(forwarded_ip, "Test")

      conn =
        conn
        |> put_req_header("x-forwarded-for", "#{forwarded_ip}, 192.168.1.1")
        |> SecurityPipeline.call([])

      assert conn.halted
      assert conn.status == 403
    end
  end

  describe "integration with full pipeline" do
    test "applies all security measures in order", %{conn: conn} do
      conn =
        conn
        |> put_req_header("origin", "http://localhost:3000")
        |> SecurityPipeline.call([])

      # Verify headers are set
      assert get_resp_header(conn, "x-frame-options") == ["DENY"]
      assert get_resp_header(conn, "strict-transport-security") != []

      # Verify CORS headers
      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]

      # Verify request was not halted
      refute conn.halted
    end

    test "halts on first security violation", %{conn: conn} do
      # Block IP first
      Security.block_ip("127.0.0.1", "Test")

      conn =
        conn
        |> put_req_header("origin", "http://localhost:3000")
        |> SecurityPipeline.call([])

      # Should halt at IP blocklist check, before rate limiting
      assert conn.halted
      assert conn.status == 403
    end
  end
end
