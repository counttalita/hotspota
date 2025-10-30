defmodule HotspotApiWeb.AuthController do
  use HotspotApiWeb, :controller

  alias HotspotApi.Accounts
  alias HotspotApi.Guardian
  alias HotspotApi.Security

  action_fallback HotspotApiWeb.FallbackController

  @doc """
  POST /api/auth/send-otp
  Sends an OTP code to the provided phone number.
  """
  def send_otp(conn, %{"phone_number" => phone_number}) do
    case Accounts.send_otp(phone_number) do
      {:ok, _otp_code} ->
        conn
        |> put_status(:ok)
        |> json(%{
          message: "OTP sent successfully",
          expires_in: 600
        })

      {:error, :rate_limit_exceeded} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{
          error: %{
            code: "rate_limit_exceeded",
            message: "Maximum 3 OTP requests per hour. Please try again later.",
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        })

      {:error, :twilio_error} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          error: %{
            code: "sms_service_error",
            message: "Failed to send SMS. Please try again.",
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: %{
            code: "validation_error",
            message: "Invalid phone number format",
            details: translate_errors(changeset),
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        })
    end
  end

  def send_otp(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: %{
        code: "missing_parameter",
        message: "phone_number is required",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    })
  end

  @doc """
  POST /api/auth/verify-otp
  Verifies the OTP code and returns a JWT token.
  """
  def verify_otp(conn, %{"phone_number" => phone_number, "code" => code}) do
    # Check rate limit before attempting verification
    case Security.check_login_rate_limit(phone_number) do
      {:ok, :allowed} ->
        verify_and_track(conn, phone_number, code)

      {:error, :too_many_attempts, retry_after} ->
        # Record failed attempt
        Security.record_auth_attempt(%{
          phone_number: phone_number,
          ip_address: Security.get_ip_address(conn),
          user_agent: get_user_agent(conn),
          success: false,
          failure_reason: "rate_limit_exceeded"
        })

        conn
        |> put_resp_header("retry-after", to_string(retry_after))
        |> put_status(:too_many_requests)
        |> json(%{
          error: %{
            code: "too_many_attempts",
            message: "Too many failed login attempts. Account locked for 15 minutes.",
            retry_after: retry_after,
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        })
    end
  end

  defp verify_and_track(conn, phone_number, code) do
    case Accounts.verify_otp(phone_number, code) do
      {:ok, user} ->
        # Record successful attempt
        Security.record_auth_attempt(%{
          phone_number: phone_number,
          ip_address: Security.get_ip_address(conn),
          user_agent: get_user_agent(conn),
          success: true
        })

        {:ok, token, _claims} = Guardian.encode_and_sign(user, %{}, ttl: {90, :days})

        conn
        |> put_status(:ok)
        |> json(%{
          token: token,
          user: %{
            id: user.id,
            phone_number: user.phone_number,
            is_premium: user.is_premium,
            alert_radius: user.alert_radius,
            notification_config: user.notification_config
          }
        })

      {:error, :invalid_or_expired_otp} ->
        # Record failed attempt
        Security.record_auth_attempt(%{
          phone_number: phone_number,
          ip_address: Security.get_ip_address(conn),
          user_agent: get_user_agent(conn),
          success: false,
          failure_reason: "invalid_otp"
        })

        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: %{
            code: "invalid_otp",
            message: "Invalid or expired OTP code",
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        })

      {:error, :too_many_attempts} ->
        Security.record_auth_attempt(%{
          phone_number: phone_number,
          ip_address: Security.get_ip_address(conn),
          user_agent: get_user_agent(conn),
          success: false,
          failure_reason: "too_many_otp_attempts"
        })

        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: %{
            code: "too_many_attempts",
            message: "Too many verification attempts. Please request a new OTP.",
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        })

      {:error, _reason} ->
        Security.record_auth_attempt(%{
          phone_number: phone_number,
          ip_address: Security.get_ip_address(conn),
          user_agent: get_user_agent(conn),
          success: false,
          failure_reason: "verification_error"
        })

        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: %{
            code: "verification_failed",
            message: "Failed to verify OTP. Please try again.",
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        })
    end
  end

  def verify_otp(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: %{
        code: "missing_parameters",
        message: "phone_number and code are required",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    })
  end

  @doc """
  GET /api/auth/me
  Returns the current authenticated user's information.
  """
  def me(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    conn
    |> put_status(:ok)
    |> json(%{
      user: %{
        id: user.id,
        phone_number: user.phone_number,
        is_premium: user.is_premium,
        alert_radius: user.alert_radius,
        notification_config: user.notification_config,
        premium_expires_at: user.premium_expires_at
      }
    })
  end

  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [user_agent | _] -> user_agent
      [] -> "unknown"
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
