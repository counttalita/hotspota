Mox.defmock(HotspotApi.TwilioMock, for: HotspotApi.TwilioBehaviour)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(HotspotApi.Repo, :manual)
