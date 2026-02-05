
# Define Policy that allows MinIO apply for certs
resource "vault_policy" "minio_pki" {
  name = "${var.vault_role_name}-pki-policy"

  policy = <<EOT
path "${var.vault_pki_mount_path}/issue/${var.vault_role_name}" {
  capabilities = ["create", "update"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOT
}

# Create AppRole that define the role of MinIO
resource "vault_approle_auth_backend_role" "minio" {
  backend        = "approle"
  role_name      = var.vault_role_name
  token_policies = ["default", vault_policy.minio_pki.name]
  token_ttl      = 3600
  token_max_ttl  = 86400
}

# Generate Secret ID for login credentials
resource "vault_approle_auth_backend_role_secret_id" "minio" {
  backend   = vault_approle_auth_backend_role.minio.backend
  role_name = vault_approle_auth_backend_role.minio.role_name
}
