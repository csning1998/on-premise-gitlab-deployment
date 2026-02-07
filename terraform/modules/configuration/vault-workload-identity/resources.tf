
# 1. Define Policy: Standard PKI access + Optional Extras
resource "vault_policy" "this" {
  name = "${var.name}-policy"

  policy = <<EOT
# Allow requesting certificates from the specific PKI Role
path "${var.pki_mount_path}/issue/${var.vault_role_name}" {
  capabilities = ["create", "update"]
}

# Allow token renewal (Standard requirement for Vault Agent/Consul Template)
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Inject extra policies (e.g., for Harbor secret reading)
${var.extra_policy_hcl}
EOT
}

# 2. Create AppRole
resource "vault_approle_auth_backend_role" "this" {
  backend        = var.approle_mount_path
  role_name      = var.name
  token_policies = ["default", vault_policy.this.name]

  token_ttl     = var.token_ttl
  token_max_ttl = var.token_max_ttl
}

# 3. Generate Secret ID (Identity Credential)
resource "vault_approle_auth_backend_role_secret_id" "this" {
  backend   = vault_approle_auth_backend_role.this.backend
  role_name = vault_approle_auth_backend_role.this.role_name
}
