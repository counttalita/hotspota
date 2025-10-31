defmodule HotspotApi.Accounts.AdminUserTest do
  use HotspotApi.DataCase, async: true

  alias HotspotApi.Accounts.AdminUser

  describe "registration_changeset/2" do
    @valid_attrs %{
      email: "admin@example.com",
      name: "Admin User",
      role: "moderator",
      password: "SecureP@ssw0rd123"
    }

    test "hashes password with Argon2" do
      changeset = AdminUser.registration_changeset(%AdminUser{}, @valid_attrs)

      assert changeset.valid?
      password_hash = get_change(changeset, :password_hash)
      assert password_hash
      assert String.starts_with?(password_hash, "$argon2")
      refute get_change(changeset, :password)
    end

    test "requires minimum 12 characters" do
      attrs = %{@valid_attrs | password: "Short1!"}
      changeset = AdminUser.registration_changeset(%AdminUser{}, attrs)

      refute changeset.valid?
      assert "must be at least 12 characters" in errors_on(changeset).password
    end

    test "requires at least one lowercase letter" do
      attrs = %{@valid_attrs | password: "NOLOWERCASE1!"}
      changeset = AdminUser.registration_changeset(%AdminUser{}, attrs)

      refute changeset.valid?
      assert "must contain at least one lowercase letter" in errors_on(changeset).password
    end

    test "requires at least one uppercase letter" do
      attrs = %{@valid_attrs | password: "nouppercase1!"}
      changeset = AdminUser.registration_changeset(%AdminUser{}, attrs)

      refute changeset.valid?
      assert "must contain at least one uppercase letter" in errors_on(changeset).password
    end

    test "requires at least one number" do
      attrs = %{@valid_attrs | password: "NoNumbersHere!"}
      changeset = AdminUser.registration_changeset(%AdminUser{}, attrs)

      refute changeset.valid?
      assert "must contain at least one number" in errors_on(changeset).password
    end

    test "requires at least one special character" do
      attrs = %{@valid_attrs | password: "NoSpecialChar1"}
      changeset = AdminUser.registration_changeset(%AdminUser{}, attrs)

      refute changeset.valid?
      assert "must contain at least one special character" in errors_on(changeset).password
    end

    test "accepts valid strong password" do
      changeset = AdminUser.registration_changeset(%AdminUser{}, @valid_attrs)
      assert changeset.valid?
    end

    test "accepts various special characters" do
      special_chars = ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")", ",", ".", "?", ":", "{", "}", "|"]

      for char <- special_chars do
        attrs = %{@valid_attrs | password: "ValidPass1#{char}abc"}
        changeset = AdminUser.registration_changeset(%AdminUser{}, attrs)
        assert changeset.valid?, "Failed for special char: #{char}"
      end
    end
  end

  describe "verify_password/2" do
    setup do
      {:ok, admin_user} =
        %AdminUser{}
        |> AdminUser.registration_changeset(%{
          email: "test@example.com",
          name: "Test Admin",
          role: "moderator",
          password: "SecureP@ssw0rd123"
        })
        |> Repo.insert()

      {:ok, admin_user: admin_user}
    end

    test "returns true for correct password", %{admin_user: admin_user} do
      assert AdminUser.verify_password(admin_user, "SecureP@ssw0rd123")
    end

    test "returns false for incorrect password", %{admin_user: admin_user} do
      refute AdminUser.verify_password(admin_user, "WrongPassword123!")
    end

    test "returns false for empty password", %{admin_user: admin_user} do
      refute AdminUser.verify_password(admin_user, "")
    end

    test "returns false for nil password", %{admin_user: admin_user} do
      refute AdminUser.verify_password(admin_user, "")
    end

    test "is case sensitive", %{admin_user: admin_user} do
      refute AdminUser.verify_password(admin_user, "securep@ssw0rd123")
      refute AdminUser.verify_password(admin_user, "SECUREP@SSW0RD123")
    end
  end

  describe "changeset/2" do
    test "validates email format" do
      changeset = AdminUser.changeset(%AdminUser{}, %{
        email: "invalid-email",
        name: "Test",
        role: "moderator"
      })

      refute changeset.valid?
      assert "must be a valid email" in errors_on(changeset).email
    end

    test "validates role inclusion" do
      changeset = AdminUser.changeset(%AdminUser{}, %{
        email: "test@example.com",
        name: "Test",
        role: "invalid_role"
      })

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).role
    end

    test "accepts valid roles" do
      valid_roles = ["super_admin", "moderator", "analyst", "partner_manager"]

      for role <- valid_roles do
        changeset = AdminUser.changeset(%AdminUser{}, %{
          email: "test@example.com",
          name: "Test",
          role: role
        })

        assert changeset.valid?, "Failed for role: #{role}"
      end
    end

    test "requires email, name, and role" do
      changeset = AdminUser.changeset(%AdminUser{}, %{})

      refute changeset.valid?
      errors = errors_on(changeset)
      assert "can't be blank" in errors.email
      assert "can't be blank" in errors.name
      # Role has a default value, so it won't be blank
    end
  end

  describe "password security" do
    test "password is redacted in inspect" do
      admin_user = %AdminUser{
        email: "test@example.com",
        password: "SecureP@ssw0rd123",
        password_hash: "$argon2id$v=19$m=65536,t=4,p=1$..."
      }

      inspected = inspect(admin_user)
      refute inspected =~ "SecureP@ssw0rd123"
      refute inspected =~ "$argon2id$"
    end

    test "different passwords produce different hashes" do
      changeset1 = AdminUser.registration_changeset(%AdminUser{}, %{
        email: "test1@example.com",
        name: "Test 1",
        role: "moderator",
        password: "SecureP@ssw0rd123"
      })

      changeset2 = AdminUser.registration_changeset(%AdminUser{}, %{
        email: "test2@example.com",
        name: "Test 2",
        role: "moderator",
        password: "DifferentP@ss456"
      })

      hash1 = get_change(changeset1, :password_hash)
      hash2 = get_change(changeset2, :password_hash)

      assert hash1 != hash2
    end

    test "same password produces different hashes due to salt" do
      password = "SecureP@ssw0rd123"

      changeset1 = AdminUser.registration_changeset(%AdminUser{}, %{
        email: "test1@example.com",
        name: "Test 1",
        role: "moderator",
        password: password
      })

      changeset2 = AdminUser.registration_changeset(%AdminUser{}, %{
        email: "test2@example.com",
        name: "Test 2",
        role: "moderator",
        password: password
      })

      hash1 = get_change(changeset1, :password_hash)
      hash2 = get_change(changeset2, :password_hash)

      # Argon2 uses random salt, so hashes should be different
      assert hash1 != hash2
    end
  end

  describe "Argon2 configuration" do
    test "uses Argon2id variant" do
      changeset = AdminUser.registration_changeset(%AdminUser{}, %{
        email: "test@example.com",
        name: "Test",
        role: "moderator",
        password: "SecureP@ssw0rd123"
      })

      password_hash = get_change(changeset, :password_hash)
      assert String.starts_with?(password_hash, "$argon2id$")
    end

    test "hash is sufficiently long" do
      changeset = AdminUser.registration_changeset(%AdminUser{}, %{
        email: "test@example.com",
        name: "Test",
        role: "moderator",
        password: "SecureP@ssw0rd123"
      })

      password_hash = get_change(changeset, :password_hash)
      # Argon2 hashes are typically 90+ characters
      assert String.length(password_hash) > 80
    end
  end
end
