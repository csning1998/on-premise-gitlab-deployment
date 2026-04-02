
output "production_role_id" {
  description = "RoleID for the Production Vault AppRole"
  value       = vault_approle_auth_backend_role.terraform_admin.role_id
}

output "production_secret_id" {
  description = "SecretID for the Production Vault AppRole"
  value       = vault_approle_auth_backend_role_secret_id.terraform_admin.secret_id
  sensitive   = true
}

output "production_approle_path" {
  description = "The mount path of the production approle backend"
  value       = vault_auth_backend.approle.path
}
