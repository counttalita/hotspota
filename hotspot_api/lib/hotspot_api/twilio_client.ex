defmodule HotspotApi.TwilioClient do
  @moduledoc """
  Real Twilio SMS client implementation.
  """

  @behaviour HotspotApi.TwilioBehaviour

  require Logger

  @impl true
  def send_sms(phone_number, message) do
    twilio_account_sid = Application.get_env(:hotspot_api, :twilio_account_sid)
    twilio_auth_token = Application.get_env(:hotspot_api, :twilio_auth_token)
    twilio_phone_number = Application.get_env(:hotspot_api, :twilio_phone_number)

    # Skip Twilio in development if credentials not configured
    if is_nil(twilio_account_sid) or is_nil(twilio_auth_token) do
      Logger.info("Skipping Twilio SMS in development. Message: #{message}")
      :ok
    else
      url = "https://api.twilio.com/2010-04-01/Accounts/#{twilio_account_sid}/Messages.json"

      body = URI.encode_query(%{
        "To" => phone_number,
        "From" => twilio_phone_number,
        "Body" => message
      })

      headers = [
        {"Authorization", "Basic #{Base.encode64("#{twilio_account_sid}:#{twilio_auth_token}")}"},
        {"Content-Type", "application/x-www-form-urlencoded"}
      ]

      case HTTPoison.post(url, body, headers) do
        {:ok, %HTTPoison.Response{status_code: status}} when status in 200..299 ->
          :ok

        {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
          Logger.error("Twilio API error: #{status} - #{body}")
          {:error, :twilio_error}

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("Twilio request failed: #{inspect(reason)}")
          {:error, :twilio_error}
      end
    end
  end
end
