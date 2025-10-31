defmodule HotspotApi.Monetization.SponsoredAlert do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sponsored_alerts" do
    field :impression_count, :integer, default: 0
    field :click_count, :integer, default: 0

    belongs_to :partner, HotspotApi.Monetization.Partner
    belongs_to :incident, HotspotApi.Incidents.Incident

    timestamps()
  end

  @doc false
  def changeset(sponsored_alert, attrs) do
    sponsored_alert
    |> cast(attrs, [:partner_id, :incident_id, :impression_count, :click_count])
    |> validate_required([:partner_id, :incident_id])
    |> foreign_key_constraint(:partner_id)
    |> foreign_key_constraint(:incident_id)
    |> unique_constraint([:partner_id, :incident_id])
  end
end
