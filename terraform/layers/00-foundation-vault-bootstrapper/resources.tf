
# Define Terraform Administrative Policy
resource "vault_policy" "terraform_admin" {
  name   = "terraform-admin-policy"
  policy = <<EOT
# [1] Data Operations: Includes read, create, update, and soft delete of the latest version
path "secret/data/on-premise-gitlab-deployment/*" {
  capabilities = ["read", "create", "update", "delete"]
}

# [2] Metadata Operations: Required for Terraform to read and purge metadata during plan and destroy
path "secret/metadata/on-premise-gitlab-deployment/*" {
  capabilities = ["read", "list", "delete"]
}

# [3] Version Deletion: Allows Terraform to mark specific old versions as deleted
path "secret/delete/on-premise-gitlab-deployment/*" {
  capabilities = ["update"]
}

# [4] Permanent Destruction: Allows Terraform to perform forced physical removal (Destroy)
path "secret/destroy/on-premise-gitlab-deployment/*" {
  capabilities = ["update"]
}
EOT
}

# Enable AppRole auth backend
resource "vault_auth_backend" "approle" {
  type = "approle"
}

# Create the Terraform AppRole
resource "vault_approle_auth_backend_role" "terraform_admin" {
  backend        = vault_auth_backend.approle.path
  role_name      = "terraform-admin-role"
  token_policies = [vault_policy.terraform_admin.name]
  token_ttl      = 3600
  token_max_ttl  = 14400
}

resource "vault_approle_auth_backend_role_secret_id" "terraform_admin" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.terraform_admin.role_name
}

resource "vault_kv_secret_v2" "terraform_admin_auth" {
  mount = "secret"
  name  = "on-premise-gitlab-deployment/credentials"
  data_json = jsonencode({
    role_id   = vault_approle_auth_backend_role.terraform_admin.role_id
    secret_id = vault_approle_auth_backend_role_secret_id.terraform_admin.secret_id
  })
}
