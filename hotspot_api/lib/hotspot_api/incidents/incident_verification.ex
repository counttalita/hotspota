defmodule HotspotApi.Incidents.IncidentVerification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "incident_verifications" do
    belongs_to :incident, HotspotApi.Incidents.Incident
    belongs_to :user, HotspotApi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(verification, attrs) do
    verification
    |> cast(attrs, [:incident_id, :user_id])
    |> validate_required([:incident_id, :user_id])
    |> foreign_key_constraint(:incident_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:incident_id, :user_id], name: :unique_incident_user_verification, message: "You have already verified this incident")
    |> validate_not_self_verification()
  end

  # Prevent users from verifying their own incidents
  defp validate_not_self_verification(changeset) do
    incident_id = get_field(changeset, :incident_id)
    user_id = get_field(changeset, :user_id)

    if incident_id && user_id do
      incident = HotspotApi.Repo.get(HotspotApi.Incidents.Incident, incident_id)

      if incident && incident.user_id == user_id do
        add_error(changeset, :user_id, "You cannot verify your own incident")
      else
        changeset
      end
    else
      changeset
    end
  end
end
