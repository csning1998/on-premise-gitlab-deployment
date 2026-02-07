
output "approle_role_id" {
  description = "The Role ID of the AppRole"
  value       = vault_approle_auth_backend_role.this.role_id
}

output "approle_secret_id" {
  description = "The Secret ID of the AppRole"
  value       = vault_approle_auth_backend_role_secret_id.this.secret_id
  sensitive   = true
}

output "approle_path" {
  description = "The path of the AppRole backend"
  value       = vault_approle_auth_backend_role.this.backend
}

output "approle_name" {
  description = "The name of the created AppRole"
  value       = vault_approle_auth_backend_role.this.role_name
}

