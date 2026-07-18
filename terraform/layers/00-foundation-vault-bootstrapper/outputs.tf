
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

output "vault_dev_endpoint" {
  description = "The address of the Vault server"
  value       = var.vault_dev_endpoint
}

output "vault_dev_ca_cert_path" {
  description = "Path to the dev Vault server's own listener TLS CA, for downstream layers connecting to this same Vault instance"
  value       = abspath(local_file.vault_dev_ca_copy.filename)
}

output "bootstrap_root_ca_certificate_pem" {
  description = "Infrastructure Root CA certificate (PEM). Signs only the Bootstrap Issuing Intermediate."
  value       = vault_pki_secret_backend_root_cert.root.certificate
}

output "bootstrap_intermediate_ca_certificate_pem" {
  description = "Bootstrap Issuing Intermediate CA certificate (PEM), signed by the Infrastructure Root CA."
  value       = vault_pki_secret_backend_root_sign_intermediate.bootstrap_int_signed.certificate
}

output "bootstrap_pki_mount_path" {
  description = "Mount path of the Bootstrap Issuing Intermediate PKI engine, used by downstream layers to request bootstrap leaf certificates."
  value       = vault_mount.pki_bootstrap_int.path
}
