defmodule HotspotApi.Communities.GroupMember do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_roles ~w(admin moderator member)

  schema "group_members" do
    field :role, :string, default: "member"
    field :joined_at, :utc_datetime
    field :notifications_enabled, :boolean, default: true

    belongs_to :group, HotspotApi.Communities.CommunityGroup
    belongs_to :user, HotspotApi.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(group_member, attrs) do
    group_member
    |> cast(attrs, [:group_id, :user_id, :role, :joined_at, :notifications_enabled])
    |> validate_required([:group_id, :user_id])
    |> validate_inclusion(:role, @valid_roles)
    |> put_joined_at()
    |> unique_constraint([:group_id, :user_id], name: :group_members_group_id_user_id_index)
  end

  defp put_joined_at(changeset) do
    case get_field(changeset, :joined_at) do
      nil -> put_change(changeset, :joined_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
