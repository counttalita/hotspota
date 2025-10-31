# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     HotspotApi.Repo.insert!(%HotspotApi.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias HotspotApi.Repo
alias HotspotApi.Admin
alias HotspotApi.Admin.AdminUser

# Create default admin user
case Admin.get_admin_by_email("admin@hotspot.app") do
  nil ->
    {:ok, admin} = Admin.create_admin(%{
      email: "admin@hotspot.app",
      password: "Left2right++",
      name: "System Administrator",
      role: "super_admin",
      is_active: true
    })
    IO.puts("✓ Created admin user: #{admin.email}")

  admin ->
    IO.puts("✓ Admin user already exists: #{admin.email}")
end

IO.puts("\n=== Seed completed ===")
IO.puts("Admin credentials:")
IO.puts("  Email: admin@hotspot.app")
IO.puts("  Password: Left2right++")
IO.puts("=====================\n")
