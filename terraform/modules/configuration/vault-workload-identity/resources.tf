
# 1. Define Policy: Standard PKI access + Optional Extras
resource "vault_policy" "this" {
  name = "${var.name}-policy"
  policy = jsonencode({
    path = merge(
      {
        "${var.pki_mount_path}/issue/${var.vault_role_name}" = { capabilities = ["create", "update"] }
      },
      var.extra_policy_hcl
    )
  })
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
