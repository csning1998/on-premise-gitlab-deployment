
output "databases" {
  description = "Created databases information"
  value       = postgresql_database.dbs
}

output "users" {
  description = "Created users information"
  value       = postgresql_role.users
  sensitive   = true
}

output "extensions" {
  description = "Created extensions information"
  value       = postgresql_extension.extensions
}
