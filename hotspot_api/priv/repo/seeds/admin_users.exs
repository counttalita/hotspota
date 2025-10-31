# Script for creating initial admin users
# Run with: mix run priv/repo/seeds/admin_users.exs

alias HotspotApi.Admin

# Create super admin user
case Admin.create_admin(%{
       email: "admin@hotspot.app",
       password: "Admin123!@#$",
       name: "Super Admin",
       role: "super_admin"
     }) do
  {:ok, admin} ->
    IO.puts("✓ Created super admin: #{admin.email}")

  {:error, changeset} ->
    IO.puts("✗ Failed to create super admin:")
    IO.inspect(changeset.errors)
end

# Create moderator user
case Admin.create_admin(%{
       email: "moderator@hotspot.app",
       password: "Moderator123!@#$",
       name: "Moderator",
       role: "moderator"
     }) do
  {:ok, admin} ->
    IO.puts("✓ Created moderator: #{admin.email}")

  {:error, changeset} ->
    IO.puts("✗ Failed to create moderator:")
    IO.inspect(changeset.errors)
end

IO.puts("\nAdmin users created successfully!")
IO.puts("You can now login with:")
IO.puts("  Email: admin@hotspot.app")
IO.puts("  Password: Admin123!@#$")
