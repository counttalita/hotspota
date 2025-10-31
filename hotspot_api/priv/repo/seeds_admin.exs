# Script for creating admin users
# Run with: mix run priv/repo/seeds_admin.exs

alias HotspotApi.Repo
alias HotspotApi.Accounts.AdminUser
import Ecto.Query

# Helper function to create or update admin user
defp create_or_update_admin(attrs) do
  case Repo.get_by(AdminUser, email: attrs.email) do
    nil ->
      %AdminUser{}
      |> AdminUser.changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, admin} ->
          IO.puts("✓ Created admin user: #{admin.email} (#{admin.role})")
          {:ok, admin}
        {:error, changeset} ->
          IO.puts("✗ Failed to create admin user: #{attrs.email}")
          IO.inspect(changeset.errors)
          {:error, changeset}
      end

    existing_admin ->
      IO.puts("⚠ Admin user already exists: #{existing_admin.email}")
      {:ok, existing_admin}
  end
end

IO.puts("\n=== Creating Admin Users ===\n")

# Create Super Admin
create_or_update_admin(%{
  email: "admin@hotspot.app",
  password: "Left2right++",
  name: "Super Admin",
  role: "super_admin",
  is_active: true
})

# Create Moderator
create_or_update_admin(%{
  email: "moderator@hotspot.app",
  password: "Left2right++",
  name: "Content Moderator",
  role: "moderator",
  is_active: true
})

# Create Analyst
create_or_update_admin(%{
  email: "analyst@hotspot.app",
  password: "Left2right++",
  name: "Data Analyst",
  role: "analyst",
  is_active: true
})

# Create Partner Manager
create_or_update_admin(%{
  email: "partner@hotspot.app",
  password: "Left2right++",
  name: "Partner Manager",
  role: "partner_manager",
  is_active: true
})

IO.puts("\n=== Admin User Creation Complete ===")
IO.puts("\n⚠️  IMPORTANT: Change default passwords immediately!")
IO.puts("Default password for all accounts: Left2right++\n")
