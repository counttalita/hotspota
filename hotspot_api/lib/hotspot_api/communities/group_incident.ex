defmodule HotspotApi.Communities.GroupIncident do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "group_incidents" do
    belongs_to :group, HotspotApi.Communities.CommunityGroup
    belongs_to :incident, HotspotApi.Incidents.Incident

    timestamps()
  end

  @doc false
  def changeset(group_incident, attrs) do
    group_incident
    |> cast(attrs, [:group_id, :incident_id])
    |> validate_required([:group_id, :incident_id])
    |> unique_constraint([:group_id, :incident_id], name: :group_incidents_group_id_incident_id_index)
  end
end
