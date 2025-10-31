defmodule HotspotApi.Guardian do
  use Guardian, otp_app: :hotspot_api

  alias HotspotApi.Accounts
  alias HotspotApi.Admin

  def subject_for_token(%{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  def subject_for_token(_, _) do
    {:error, :no_id_provided}
  end

  def resource_from_claims(%{"sub" => id, "type" => "admin"}) do
    case Admin.get_admin!(id) do
      nil -> {:error, :admin_not_found}
      admin -> {:ok, admin}
    end
  rescue
    Ecto.NoResultsError -> {:error, :admin_not_found}
  end

  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user!(id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  rescue
    Ecto.NoResultsError -> {:error, :user_not_found}
  end

  def resource_from_claims(_claims) do
    {:error, :no_subject}
  end
end
