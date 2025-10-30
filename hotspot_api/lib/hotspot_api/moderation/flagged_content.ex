defmodule HotspotApi.Moderation.FlaggedContent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "flagged_content" do
    field :content_type, :string
    field :flag_reason, :string
    field :moderation_score, :float
    field :status, :string, default: "pending"
    field :reviewed_by, :binary_id
    field :reviewed_at, :utc_datetime

    belongs_to :incident, HotspotApi.Incidents.Incident
    belongs_to :user, HotspotApi.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(flagged_content, attrs) do
    flagged_content
    |> cast(attrs, [:incident_id, :user_id, :content_type, :flag_reason, :moderation_score, :status, :reviewed_by, :reviewed_at])
    |> validate_required([:content_type, :flag_reason])
    |> validate_inclusion(:content_type, ["image", "text"])
    |> validate_inclusion(:status, ["pending", "approved", "rejected"])
    |> foreign_key_constraint(:incident_id)
    |> foreign_key_constraint(:user_id)
  end
end
