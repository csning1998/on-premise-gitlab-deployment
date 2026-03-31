
output "role_id" {
  description = "The RoleID of the Terraform admin AppRole"
  value       = vault_approle_auth_backend_role.terraform_admin.role_id
}

output "approle_path" {
  description = "The path where AppRole auth is enabled"
  value       = vault_auth_backend.approle.path
}

output "role_name" {
  description = "The name of the AppRole"
  value       = vault_approle_auth_backend_role.terraform_admin.role_name
}

output "secret_id" {
  description = "The SecretID of the Terraform admin AppRole"
  value       = vault_approle_auth_backend_role_secret_id.terraform_admin.secret_id
  sensitive   = true
}

output "vault_addr" {
  description = "The address of the Vault server"
  value       = var.vault_dev_addr
}
