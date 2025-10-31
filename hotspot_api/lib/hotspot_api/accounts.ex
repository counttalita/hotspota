defmodule HotspotApi.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias HotspotApi.Repo

  alias HotspotApi.Accounts.{User, OtpCode, AdminUser, AdminAuditLog, EmergencyContact, PanicEvent}

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
  Updates a user's premium status and expiration date.
  """
  def update_user_premium_status(user_id, is_premium, expires_at) do
    user = get_user!(user_id)

    attrs = %{
      is_premium: is_premium,
      premium_expires_at: expires_at
    }

    # Update alert radius based on premium status
    attrs = if is_premium do
      # Premium users can have up to 10km radius
      Map.put(attrs, :alert_radius, min(user.alert_radius, 10000))
    else
      # Free users limited to 2km
      Map.put(attrs, :alert_radius, min(user.alert_radius, 2000))
    end

    update_user(user, attrs)
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
      # Generate 6-digit OTP using secure random
      code = generate_secure_otp()
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

  defp generate_secure_otp do
    # Use cryptographically secure random number generation
    <<a::32, b::32, c::32>> = :crypto.strong_rand_bytes(12)
    code = rem(abs(a + b + c), 1_000_000)
    code |> Integer.to_string() |> String.pad_leading(6, "0")
  end

  defp send_twilio_sms(phone_number, code) do
    twilio_client = Application.get_env(:hotspot_api, :twilio_client, HotspotApi.TwilioClient)
    message = "Your Hotspot verification code is: #{code}"
    twilio_client.send_sms(phone_number, message)
  end

  ## Admin Users

  @doc """
  Lists all admin users.
  """
  def list_admin_users do
    Repo.all(AdminUser)
  end

  @doc """
  Gets a single admin user by ID.
  """
  def get_admin_user!(id), do: Repo.get!(AdminUser, id)

  @doc """
  Gets an admin user by email.
  """
  def get_admin_user_by_email(email) do
    Repo.get_by(AdminUser, email: email)
  end

  @doc """
  Creates an admin user with password hashing.
  """
  def create_admin_user(attrs) do
    %AdminUser{}
    |> AdminUser.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an admin user.
  """
  def update_admin_user(%AdminUser{} = admin_user, attrs) do
    admin_user
    |> AdminUser.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates admin user password.
  """
  def update_admin_password(%AdminUser{} = admin_user, password) do
    admin_user
    |> AdminUser.registration_changeset(%{password: password})
    |> Repo.update()
  end

  @doc """
  Authenticates an admin user with email and password.
  Returns {:ok, admin_user} if successful, {:error, reason} otherwise.
  """
  def authenticate_admin(email, password) do
    admin_user = get_admin_user_by_email(email)

    cond do
      is_nil(admin_user) ->
        # Run password hash to prevent timing attacks
        Argon2.no_user_verify()
        {:error, :invalid_credentials}

      not admin_user.is_active ->
        {:error, :account_inactive}

      AdminUser.verify_password(admin_user, password) ->
        # Update last login
        update_admin_user(admin_user, %{last_login_at: DateTime.utc_now()})
        {:ok, admin_user}

      true ->
        {:error, :invalid_credentials}
    end
  end

  @doc """
  Deactivates an admin user account.
  """
  def deactivate_admin_user(%AdminUser{} = admin_user) do
    update_admin_user(admin_user, %{is_active: false})
  end

  ## Admin Audit Logs

  @doc """
  Creates an audit log entry for admin actions.
  """
  def create_audit_log(attrs) do
    %AdminAuditLog{}
    |> AdminAuditLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists audit logs with optional filters.
  """
  def list_audit_logs(filters \\ %{}) do
    AdminAuditLog
    |> apply_audit_log_filters(filters)
    |> order_by([a], desc: a.inserted_at)
    |> limit(100)
    |> Repo.all()
    |> Repo.preload(:admin_user)
  end

  defp apply_audit_log_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:admin_user_id, admin_user_id}, query ->
        where(query, [a], a.admin_user_id == ^admin_user_id)

      {:action, action}, query ->
        where(query, [a], a.action == ^action)

      {:resource_type, resource_type}, query ->
        where(query, [a], a.resource_type == ^resource_type)

      {:resource_id, resource_id}, query ->
        where(query, [a], a.resource_id == ^resource_id)

      _, query ->
        query
    end)
  end

  ## Emergency Contacts

  @doc """
  Lists all emergency contacts for a user.
  """
  def list_emergency_contacts(user_id) do
    from(ec in EmergencyContact,
      where: ec.user_id == ^user_id,
      order_by: [asc: ec.priority]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single emergency contact.
  """
  def get_emergency_contact!(id), do: Repo.get!(EmergencyContact, id)

  @doc """
  Creates an emergency contact for a user.
  Maximum 5 contacts per user.
  """
  def create_emergency_contact(user_id, attrs) do
    # Check if user already has 5 contacts
    contact_count = from(ec in EmergencyContact,
      where: ec.user_id == ^user_id,
      select: count(ec.id)
    )
    |> Repo.one()

    if contact_count >= 5 do
      {:error, :max_contacts_reached}
    else
      attrs = Map.put(attrs, :user_id, user_id)

      %EmergencyContact{}
      |> EmergencyContact.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Updates an emergency contact.
  """
  def update_emergency_contact(%EmergencyContact{} = contact, attrs) do
    contact
    |> EmergencyContact.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an emergency contact.
  """
  def delete_emergency_contact(%EmergencyContact{} = contact) do
    Repo.delete(contact)
  end

  @doc """
  Gets an emergency contact by ID and user ID (for authorization).
  """
  def get_user_emergency_contact(user_id, contact_id) do
    from(ec in EmergencyContact,
      where: ec.id == ^contact_id and ec.user_id == ^user_id
    )
    |> Repo.one()
  end

  ## Panic Events

  @doc """
  Creates a panic event and triggers emergency alerts.
  """
  def trigger_panic_button(user_id, latitude, longitude) do
    user = get_user!(user_id) |> Repo.preload(:emergency_contacts)

    # Create panic event
    panic_attrs = %{
      user_id: user_id,
      latitude: latitude,
      longitude: longitude,
      status: "active"
    }

    case %PanicEvent{}
         |> PanicEvent.changeset(panic_attrs)
         |> Repo.insert() do
      {:ok, panic_event} ->
        # Send alerts to emergency contacts
        send_emergency_alerts(user, panic_event)
        {:ok, panic_event}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Lists panic events for a user.
  """
  def list_panic_events(user_id) do
    from(pe in PanicEvent,
      where: pe.user_id == ^user_id,
      order_by: [desc: pe.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single panic event.
  """
  def get_panic_event!(id), do: Repo.get!(PanicEvent, id)

  @doc """
  Resolves a panic event.
  """
  def resolve_panic_event(panic_event_id, notes \\ nil) do
    panic_event = get_panic_event!(panic_event_id)

    panic_event
    |> PanicEvent.changeset(%{
      status: "resolved",
      resolved_at: DateTime.utc_now(),
      notes: notes
    })
    |> Repo.update()
  end

  @doc """
  Cancels a panic event.
  """
  def cancel_panic_event(panic_event_id) do
    panic_event = get_panic_event!(panic_event_id)

    panic_event
    |> PanicEvent.changeset(%{
      status: "cancelled",
      resolved_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc """
  Gets the active panic event for a user, if any.
  """
  def get_active_panic_event(user_id) do
    from(pe in PanicEvent,
      where: pe.user_id == ^user_id and pe.status == "active",
      order_by: [desc: pe.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  defp send_emergency_alerts(user, panic_event) do
    # Sort contacts by priority
    contacts = Enum.sort_by(user.emergency_contacts, & &1.priority)

    # Generate Google Maps link
    maps_link = "https://www.google.com/maps?q=#{panic_event.latitude},#{panic_event.longitude}"

    # Send SMS to each emergency contact
    Enum.each(contacts, fn contact ->
      message = """
      🚨 EMERGENCY ALERT from #{user.phone_number}

      They have activated their panic button and may need help!

      Location: #{maps_link}

      Time: #{Calendar.strftime(panic_event.inserted_at, "%Y-%m-%d %H:%M:%S UTC")}

      This is an automated message from Hotspot Safety App.
      """

      # Send SMS via Twilio
      twilio_client = Application.get_env(:hotspot_api, :twilio_client, HotspotApi.TwilioClient)
      twilio_client.send_sms(contact.phone_number, message)

      # Also send push notification if contact is a Hotspot user
      case get_user_by_phone(contact.phone_number) do
        nil -> :ok
        contact_user ->
          HotspotApi.Notifications.send_emergency_notification(
            contact_user.id,
            user.phone_number,
            panic_event.latitude,
            panic_event.longitude
          )
      end
    end)

    :ok
  end

end
