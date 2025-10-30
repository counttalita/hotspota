defmodule HotspotApi.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias HotspotApi.Repo

  alias HotspotApi.Accounts.{User, OtpCode}

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  @doc """
  Gets a user by phone number.
  """
  def get_user_by_phone(phone_number) do
    Repo.get_by(User, phone_number: phone_number)
  end

  @doc """
  Sends an OTP code to the given phone number via Twilio.
  Returns {:ok, otp_code} if successful, {:error, reason} otherwise.
  """
  def send_otp(phone_number) do
    # Check rate limiting - max 3 OTP requests per phone per hour
    one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600, :second)

    recent_otps_count =
      from(o in OtpCode,
        where: o.phone_number == ^phone_number and o.inserted_at > ^one_hour_ago
      )
      |> Repo.aggregate(:count)

    if recent_otps_count >= 3 do
      {:error, :rate_limit_exceeded}
    else
      # Generate 6-digit OTP
      code = :rand.uniform(999_999) |> Integer.to_string() |> String.pad_leading(6, "0")
      expires_at = DateTime.utc_now() |> DateTime.add(600, :second) # 10 minutes

      # Create OTP record
      otp_attrs = %{
        phone_number: phone_number,
        code: code,
        expires_at: expires_at
      }

      case %OtpCode{}
           |> OtpCode.changeset(otp_attrs)
           |> Repo.insert() do
        {:ok, otp_code} ->
          # Send OTP via Twilio
          case send_twilio_sms(phone_number, code) do
            :ok -> {:ok, otp_code}
            {:error, reason} -> {:error, reason}
          end

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Verifies an OTP code for the given phone number.
  Returns {:ok, user} if successful, {:error, reason} otherwise.
  """
  def verify_otp(phone_number, code) do
    now = DateTime.utc_now()

    # Find the most recent unverified OTP for this phone number
    otp_code =
      from(o in OtpCode,
        where: o.phone_number == ^phone_number and
               o.code == ^code and
               o.verified == false and
               o.expires_at > ^now,
        order_by: [desc: o.inserted_at],
        limit: 1
      )
      |> Repo.one()

    case otp_code do
      nil ->
        {:error, :invalid_or_expired_otp}

      otp ->
        # Check attempts
        if otp.attempts >= 3 do
          {:error, :too_many_attempts}
        else
          # Mark OTP as verified
          otp
          |> Ecto.Changeset.change(%{verified: true, attempts: otp.attempts + 1})
          |> Repo.update()

          # Get or create user
          case get_user_by_phone(phone_number) do
            nil ->
              create_user(%{
                phone_number: phone_number,
                is_premium: false,
                alert_radius: 2000,
                notification_config: %{}
              })

            user ->
              {:ok, user}
          end
        end
    end
  end

  defp send_twilio_sms(phone_number, code) do
    twilio_account_sid = Application.get_env(:hotspot_api, :twilio_account_sid)
    twilio_auth_token = Application.get_env(:hotspot_api, :twilio_auth_token)
    twilio_phone_number = Application.get_env(:hotspot_api, :twilio_phone_number)

    # Skip Twilio in development if credentials not configured
    if is_nil(twilio_account_sid) or is_nil(twilio_auth_token) do
      require Logger
      Logger.info("Skipping Twilio SMS in development. OTP code: #{code}")
      :ok
    else
      url = "https://api.twilio.com/2010-04-01/Accounts/#{twilio_account_sid}/Messages.json"

      body = URI.encode_query(%{
        "To" => phone_number,
        "From" => twilio_phone_number,
        "Body" => "Your Hotspot verification code is: #{code}"
      })

      headers = [
        {"Authorization", "Basic #{Base.encode64("#{twilio_account_sid}:#{twilio_auth_token}")}"},
        {"Content-Type", "application/x-www-form-urlencoded"}
      ]

      case HTTPoison.post(url, body, headers) do
        {:ok, %HTTPoison.Response{status_code: status}} when status in 200..299 ->
          :ok

        {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
          require Logger
          Logger.error("Twilio API error: #{status} - #{body}")
          {:error, :twilio_error}

        {:error, %HTTPoison.Error{reason: reason}} ->
          require Logger
          Logger.error("Twilio request failed: #{inspect(reason)}")
          {:error, :twilio_error}
      end
    end
  end

end
