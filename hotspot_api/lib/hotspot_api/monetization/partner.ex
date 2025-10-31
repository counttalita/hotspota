defmodule HotspotApi.Monetization.Partner do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @partner_types ["insurance", "security", "roadside_assistance", "other"]

  schema "partners" do
    field :name, :string
    field :logo_url, :string
    field :partner_type, :string
    field :service_regions, :map
    field :is_active, :boolean, default: true
    field :monthly_fee, :decimal
    field :contract_start, :date
    field :contract_end, :date
    field :contact_email, :string
    field :contact_phone, :string

    has_many :sponsored_alerts, HotspotApi.Monetization.SponsoredAlert

    timestamps()
  end

  @doc false
  def changeset(partner, attrs) do
    partner
    |> cast(attrs, [
      :name,
      :logo_url,
      :partner_type,
      :service_regions,
      :is_active,
      :monthly_fee,
      :contract_start,
      :contract_end,
      :contact_email,
      :contact_phone
    ])
    |> validate_required([:name, :partner_type])
    |> validate_inclusion(:partner_type, @partner_types)
    |> validate_format(:contact_email, ~r/@/, message: "must be a valid email")
  end
end
