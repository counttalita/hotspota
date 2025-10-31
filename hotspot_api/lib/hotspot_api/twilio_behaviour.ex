defmodule HotspotApi.TwilioBehaviour do
  @moduledoc """
  Behaviour for Twilio SMS sending to enable mocking in tests.
  """

  @callback send_sms(phone_number :: String.t(), message :: String.t()) :: :ok | {:error, term()}
end
