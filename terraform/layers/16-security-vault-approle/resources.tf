
# 1. Define Granular Administrative Policy for Production
# Restricts access to business-specific paths (PKI, KV) and admin tasks.
resource "vault_policy" "production_admin" {
  provider = vault.production
  name     = "production-terraform-admin-policy"

  policy = jsonencode({
    path = local.admin_policy_rules
  })
}

# 2. Enable AppRole auth backend on production cluster
resource "vault_auth_backend" "approle" {
  provider = vault.production
  type     = "approle"
  path     = "approle"
}

# 3. Create the Production Terraform Admin Role
resource "vault_approle_auth_backend_role" "terraform_admin" {
  provider       = vault.production
  backend        = vault_auth_backend.approle.path
  role_name      = "production-terraform-admin"
  token_policies = [vault_policy.production_admin.name]
  token_ttl      = 3600
  token_max_ttl  = 14400
}

# 4. Generate the persistent SecretID for downstream layers
resource "vault_approle_auth_backend_role_secret_id" "terraform_admin" {
  provider  = vault.production
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.terraform_admin.role_name
}
