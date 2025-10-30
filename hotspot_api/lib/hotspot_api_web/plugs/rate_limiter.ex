defmodule HotspotApiWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug using Hammer.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  @doc """
  Rate limit for incident reporting: 1 report per minute per user.
  """
  def call(conn, _opts) do
    user = Guardian.Plug.current_resource(conn)

    if user do
      case Hammer.check_rate("incident_report:#{user.id}", 60_000, 1) do
        {:allow, _count} ->
          conn
        {:deny, _limit} ->
          conn
          |> put_status(:too_many_requests)
          |> put_view(json: HotspotApiWeb.ErrorJSON)
          |> render(:"429", message: "Rate limit exceeded. You can only report 1 incident per minute.")
          |> halt()
      end
    else
      conn
    end
  end
end
