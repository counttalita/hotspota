defmodule HotspotApi.Security.IntrusionAlert do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "intrusion_alerts" do
    field :ip_address, :string
    field :attack_type, :string
    field :request_path, :string
    field :request_params, :map
    field :severity, :string
    field :auto_blocked, :boolean, default: false
    field :created_at, :utc_datetime
  end

  @doc false
  def changeset(intrusion_alert, attrs) do
    intrusion_alert
    |> cast(attrs, [:ip_address, :attack_type, :request_path, :request_params, :severity, :auto_blocked])
    |> validate_required([:ip_address, :attack_type, :severity])
    |> validate_inclusion(:severity, ["low", "medium", "high", "critical"])
  end
end
