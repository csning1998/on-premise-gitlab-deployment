
# Define Policy that allows Harbor apply for certs
resource "vault_policy" "dev_harbor_pki" {
  name = "${var.vault_role_name}-pki-policy"

  policy = <<EOT
path "${var.vault_pki_mount_path}/issue/${var.vault_role_name}" {
  capabilities = ["create", "update"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "secret/data/on-premise-gitlab-deployment/dev-harbor/*" {
  capabilities = ["read"]
}
EOT
}

# Create AppRole that define the role of Harbor
resource "vault_approle_auth_backend_role" "dev_harbor" {
  backend        = "approle"
  role_name      = var.vault_role_name
  token_policies = ["default", vault_policy.dev_harbor_pki.name]

  token_ttl     = 60 * 60
  token_max_ttl = 60 * 60 * 24
}

# Generate Secret ID for login credentials
resource "vault_approle_auth_backend_role_secret_id" "dev_harbor" {
  backend   = vault_approle_auth_backend_role.dev_harbor.backend
  role_name = vault_approle_auth_backend_role.dev_harbor.role_name
}
