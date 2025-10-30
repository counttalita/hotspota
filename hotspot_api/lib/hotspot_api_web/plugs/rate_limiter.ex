defmodule HotspotApiWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug using Hammer.
  Prevents abuse by limiting requests per user or IP address.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @doc """
  Rate limits incident creation to 5 per hour per user.
  """
  def init(opts), do: opts

  def call(conn, _opts) do
    check_incident_rate_limit(conn, [])
  end

  def check_incident_rate_limit(conn, _opts) do
    user_id = get_user_id(conn)

    if user_id do
      case Hammer.check_rate("incident:#{user_id}", 60_000 * 60, 5) do
        {:allow, _count} ->
          conn

        {:deny, limit} ->
          conn
          |> put_status(:too_many_requests)
          |> json(%{
            error: "Rate limit exceeded",
            message: "You can only create #{limit} incidents per hour. Please try again later.",
            retry_after: 3600
          })
          |> halt()
      end
    else
      conn
    end
  end

  defp get_user_id(conn) do
    case conn.assigns[:current_user] do
      nil -> nil
      user -> user.id
    end
  end

  @doc """
  Rate limits API requests to 100 per minute per IP.
  """
  def check_api_rate_limit(conn, _opts) do
    ip_address = HotspotApi.Security.get_ip_address(conn)

    case Hammer.check_rate("api:#{ip_address}", 60_000, 100) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{
          error: "Rate limit exceeded",
          message: "Too many requests. Please slow down.",
          retry_after: 60
        })
        |> halt()
    end
  end

  @doc """
  Rate limits OTP requests to 3 per hour per phone number.
  """
  def check_otp_rate_limit(conn, _opts) do
    phone_number = conn.params["phone_number"]

    if phone_number do
      case Hammer.check_rate("otp:#{phone_number}", 60_000 * 60, 3) do
        {:allow, _count} ->
          conn

        {:deny, _limit} ->
          conn
          |> put_status(:too_many_requests)
          |> json(%{
            error: "Rate limit exceeded",
            message: "Too many OTP requests. Please try again in 1 hour.",
            retry_after: 3600
          })
          |> halt()
      end
    else
      conn
    end
  end

  @doc """
  Rate limits verification attempts to 10 per hour per user.
  """
  def check_verification_rate_limit(conn, _opts) do
    user_id = get_user_id(conn)

    if user_id do
      case Hammer.check_rate("verification:#{user_id}", 60_000 * 60, 10) do
        {:allow, _count} ->
          conn

        {:deny, _limit} ->
          conn
          |> put_status(:too_many_requests)
          |> json(%{
            error: "Rate limit exceeded",
            message: "Too many verification attempts. Please try again later.",
            retry_after: 3600
          })
          |> halt()
      end
    else
      conn
    end
  end
end
