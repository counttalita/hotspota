defmodule HotspotApi.Moderation.ImageHash do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "image_hashes" do
    field :hash, :string

    belongs_to :incident, HotspotApi.Incidents.Incident

    timestamps()
  end

  @doc false
  def changeset(image_hash, attrs) do
    image_hash
    |> cast(attrs, [:hash, :incident_id])
    |> validate_required([:hash])
    |> unique_constraint(:hash)
    |> foreign_key_constraint(:incident_id)
  end
end
