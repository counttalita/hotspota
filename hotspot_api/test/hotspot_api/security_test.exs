defmodule HotspotApi.SecurityTest do
  use HotspotApi.DataCase, async: true

  alias HotspotApi.Security

  describe "ip_blocked?/1" do
    test "returns false for non-blocked IP" do
      refute Security.ip_blocked?("192.168.1.1")
    end

    test "returns true for permanently blocked IP" do
      {:ok, _} = Security.block_ip("192.168.1.100", "Test block", permanent: true)
      assert Security.ip_blocked?("192.168.1.100")
    end

    test "returns true for temporarily blocked IP within expiry" do
      {:ok, _} = Security.block_ip("192.168.1.101", "Test block", duration_seconds: 3600)
      assert Security.ip_blocked?("192.168.1.101")
    end

    test "returns false for expired temporary block" do
      # Block with -1 second duration (already expired)
      expires_at = DateTime.utc_now() |> DateTime.add(-1, :second)

      %Security.IPBlocklist{}
      |> Security.IPBlocklist.changeset(%{
        ip_address: "192.168.1.102",
        reason: "Test expired",
        expires_at: expires_at,
        is_permanent: false
      })
      |> Repo.insert!()

      refute Security.ip_blocked?("192.168.1.102")
    end
  end

  describe "block_ip/3" do
    test "blocks IP temporarily with default duration" do
      {:ok, block} = Security.block_ip("192.168.1.200", "Suspicious activity")

      assert block.ip_address == "192.168.1.200"
      assert block.reason == "Suspicious activity"
      refute block.is_permanent
      assert block.expires_at
    end

    test "blocks IP permanently" do
      {:ok, block} = Security.block_ip("192.168.1.201", "Known attacker", permanent: true)

      assert block.ip_address == "192.168.1.201"
      assert block.is_permanent
      assert is_nil(block.expires_at)
    end

    test "blocks IP with custom duration" do
      {:ok, block} = Security.block_ip("192.168.1.202", "Rate limit", duration_seconds: 7200)

      assert block.ip_address == "192.168.1.202"
      refute block.is_permanent

      # Check expires_at is approximately 2 hours from now
      expected_expiry = DateTime.utc_now() |> DateTime.add(7200, :second)
      diff = DateTime.diff(block.expires_at, expected_expiry, :second)
      assert abs(diff) < 5
    end

    test "updates existing block on conflict" do
      {:ok, _} = Security.block_ip("192.168.1.203", "First reason")
      {:ok, updated} = Security.block_ip("192.168.1.203", "Updated reason")

      assert updated.reason == "Updated reason"
    end
  end

  describe "unblock_ip/1" do
    test "removes IP from blocklist" do
      {:ok, _} = Security.block_ip("192.168.1.210", "Test")
      assert Security.ip_blocked?("192.168.1.210")

      {count, _} = Security.unblock_ip("192.168.1.210")
      assert count == 1
      refute Security.ip_blocked?("192.168.1.210")
    end

    test "returns 0 for non-existent IP" do
      {count, _} = Security.unblock_ip("192.168.1.211")
      assert count == 0
    end
  end

  describe "check_login_rate_limit/1" do
    test "allows login when no recent failed attempts" do
      assert {:ok, :allowed} = Security.check_login_rate_limit("+27123456789")
    end

    test "blocks login after 5 failed attempts within 15 minutes" do
      phone = "+27123456790"

      # Create 5 failed attempts
      for _ <- 1..5 do
        Security.record_auth_attempt(%{
          phone_number: phone,
          ip_address: "192.168.1.1",
          success: false,
          failure_reason: "invalid_otp"
        })
      end

      assert {:error, :too_many_attempts, 900} = Security.check_login_rate_limit(phone)
    end

    test "allows login when failed attempts are older than 15 minutes" do
      phone = "+27123456791"
      sixteen_minutes_ago = DateTime.utc_now() |> DateTime.add(-16 * 60, :second) |> DateTime.truncate(:second)

      # Create old failed attempts
      for _ <- 1..5 do
        %Security.AuthAttempt{}
        |> Security.AuthAttempt.changeset(%{
          phone_number: phone,
          ip_address: "192.168.1.1",
          success: false,
          failure_reason: "invalid_otp"
        })
        |> Ecto.Changeset.put_change(:created_at, sixteen_minutes_ago)
        |> Repo.insert!()
      end

      assert {:ok, :allowed} = Security.check_login_rate_limit(phone)
    end
  end

  describe "record_auth_attempt/1" do
    test "records successful authentication attempt" do
      {:ok, attempt} = Security.record_auth_attempt(%{
        phone_number: "+27123456792",
        ip_address: "192.168.1.50",
        user_agent: "Mozilla/5.0",
        success: true
      })

      assert attempt.phone_number == "+27123456792"
      assert attempt.ip_address == "192.168.1.50"
      assert attempt.success
      assert is_nil(attempt.failure_reason)
    end

    test "records failed authentication attempt with reason" do
      {:ok, attempt} = Security.record_auth_attempt(%{
        phone_number: "+27123456793",
        ip_address: "192.168.1.51",
        success: false,
        failure_reason: "invalid_otp"
      })

      assert attempt.phone_number == "+27123456793"
      refute attempt.success
      assert attempt.failure_reason == "invalid_otp"
    end
  end

  describe "detect_sql_injection?/1" do
    test "detects OR-based SQL injection" do
      assert Security.detect_sql_injection?("1' OR '1'='1")
      assert Security.detect_sql_injection?("admin' OR 1=1--")
    end

    test "detects UNION SELECT injection" do
      assert Security.detect_sql_injection?("1 UNION SELECT * FROM users")
    end

    test "detects DROP TABLE injection" do
      assert Security.detect_sql_injection?("'; DROP TABLE users; --")
    end

    test "detects SQL comments" do
      assert Security.detect_sql_injection?("admin'--")
      assert Security.detect_sql_injection?("/* comment */ SELECT")
    end

    test "returns false for safe input" do
      refute Security.detect_sql_injection?("normal text")
      refute Security.detect_sql_injection?("user@example.com")
      refute Security.detect_sql_injection?("John Doe")
    end

    test "returns false for non-string input" do
      refute Security.detect_sql_injection?(nil)
      refute Security.detect_sql_injection?(123)
    end
  end

  describe "detect_xss?/1" do
    test "detects script tags" do
      assert Security.detect_xss?("<script>alert('xss')</script>")
      assert Security.detect_xss?("<SCRIPT>alert('xss')</SCRIPT>")
    end

    test "detects iframe tags" do
      assert Security.detect_xss?("<iframe src='evil.com'></iframe>")
    end

    test "detects javascript protocol" do
      assert Security.detect_xss?("javascript:alert('xss')")
    end

    test "detects event handlers" do
      assert Security.detect_xss?("<img onerror='alert(1)'>")
      assert Security.detect_xss?("<body onload='alert(1)'>")
      assert Security.detect_xss?("<div onclick='alert(1)'>")
    end

    test "detects img tags with src" do
      assert Security.detect_xss?("<img src='x' onerror='alert(1)'>")
    end

    test "returns false for safe input" do
      refute Security.detect_xss?("normal text")
      refute Security.detect_xss?("This is a description")
    end

    test "returns false for non-string input" do
      refute Security.detect_xss?(nil)
      refute Security.detect_xss?(123)
    end
  end

  describe "detect_path_traversal?/1" do
    test "detects ../ sequences" do
      assert Security.detect_path_traversal?("../../etc/passwd")
      assert Security.detect_path_traversal?("../../../secret.txt")
    end

    test "detects URL-encoded traversal" do
      assert Security.detect_path_traversal?("..%2F..%2Fetc%2Fpasswd")
      assert Security.detect_path_traversal?("%2e%2e/etc/passwd")
    end

    test "detects /etc/passwd access" do
      assert Security.detect_path_traversal?("/etc/passwd")
    end

    test "detects Windows system paths" do
      assert Security.detect_path_traversal?("windows/system")
    end

    test "returns false for safe paths" do
      refute Security.detect_path_traversal?("uploads/image.jpg")
      refute Security.detect_path_traversal?("documents/report.pdf")
    end

    test "returns false for non-string input" do
      refute Security.detect_path_traversal?(nil)
      refute Security.detect_path_traversal?(123)
    end
  end

  describe "sanitize_html/1" do
    test "escapes HTML special characters" do
      input = "<script>alert('xss')</script>"
      output = Security.sanitize_html(input)

      assert output =~ "&lt;script&gt;"
      assert output =~ "&lt;/script&gt;"
      refute output =~ "<script>"
    end

    test "escapes quotes and ampersands" do
      input = "Tom & Jerry's \"Adventure\""
      output = Security.sanitize_html(input)

      assert output =~ "&amp;"
      assert output =~ "&#39;"
      assert output =~ "&quot;"
    end

    test "returns nil for nil input" do
      assert is_nil(Security.sanitize_html(nil))
    end
  end

  describe "create_intrusion_alert/1" do
    test "creates intrusion alert with all fields" do
      {:ok, alert} = Security.create_intrusion_alert(%{
        ip_address: "192.168.1.100",
        attack_type: "sql_injection",
        request_path: "/api/v1/incidents",
        request_params: %{"id" => "1' OR '1'='1"},
        severity: "high",
        auto_blocked: true
      })

      assert alert.ip_address == "192.168.1.100"
      assert alert.attack_type == "sql_injection"
      assert alert.severity == "high"
      assert alert.auto_blocked
    end

    test "validates severity levels" do
      assert {:error, changeset} = Security.create_intrusion_alert(%{
        ip_address: "192.168.1.101",
        attack_type: "test",
        severity: "invalid",
        auto_blocked: false
      })

      assert "is invalid" in errors_on(changeset).severity
    end
  end

  describe "log_event/1" do
    test "logs security event" do
      {:ok, event} = Security.log_event(%{
        event_type: "failed_login",
        ip_address: "192.168.1.50",
        details: %{"reason" => "invalid_password"},
        severity: "medium"
      })

      assert event.event_type == "failed_login"
      assert event.ip_address == "192.168.1.50"
      assert event.severity == "medium"
    end
  end

  describe "list_security_events/1" do
    setup do
      # Create test events
      {:ok, _} = Security.log_event(%{
        event_type: "failed_login",
        severity: "medium"
      })

      {:ok, _} = Security.log_event(%{
        event_type: "intrusion_detected",
        severity: "high"
      })

      :ok
    end

    test "lists all events without filters" do
      events = Security.list_security_events()
      assert length(events) >= 2
    end

    test "filters by event_type" do
      events = Security.list_security_events(%{event_type: "failed_login"})
      assert length(events) >= 1
      assert Enum.all?(events, fn e -> e.event_type == "failed_login" end)
    end

    test "filters by severity" do
      events = Security.list_security_events(%{severity: "high"})
      assert length(events) >= 1
      assert Enum.all?(events, fn e -> e.severity == "high" end)
    end
  end

  describe "get_failed_attempts_by_ip/2" do
    test "returns failed attempts for IP within time window" do
      ip = "192.168.1.150"

      # Create failed attempts
      for _ <- 1..3 do
        Security.record_auth_attempt(%{
          ip_address: ip,
          success: false,
          failure_reason: "invalid_otp"
        })
      end

      attempts = Security.get_failed_attempts_by_ip(ip, 60)
      assert length(attempts) == 3
    end

    test "excludes successful attempts" do
      ip = "192.168.1.151"

      Security.record_auth_attempt(%{
        ip_address: ip,
        success: true
      })

      Security.record_auth_attempt(%{
        ip_address: ip,
        success: false,
        failure_reason: "invalid_otp"
      })

      attempts = Security.get_failed_attempts_by_ip(ip, 60)
      assert length(attempts) == 1
      refute hd(attempts).success
    end

    test "excludes attempts outside time window" do
      ip = "192.168.1.152"
      two_hours_ago = DateTime.utc_now() |> DateTime.add(-2 * 60 * 60, :second) |> DateTime.truncate(:second)

      # Create old attempt
      %Security.AuthAttempt{}
      |> Security.AuthAttempt.changeset(%{
        ip_address: ip,
        success: false,
        failure_reason: "invalid_otp"
      })
      |> Ecto.Changeset.put_change(:created_at, two_hours_ago)
      |> Repo.insert!()

      attempts = Security.get_failed_attempts_by_ip(ip, 60)
      assert length(attempts) == 0
    end
  end
end
