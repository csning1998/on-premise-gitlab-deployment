
# Define Policy that allows Redis apply for certs
resource "vault_policy" "redis_pki" {
  name = "redis-pki-policy"

  policy = <<EOT
path "pki/prod/issue/redis-role" {
  capabilities = ["create", "update"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOT
}

# Create AppRole that define the role of Redis
resource "vault_approle_auth_backend_role" "redis" {
  backend        = "approle"
  role_name      = var.vault_role_name
  token_policies = ["default", vault_policy.redis_pki.name]
  token_ttl      = 3600
  token_max_ttl  = 86400
}

# Generate Secret ID for login credentials
resource "vault_approle_auth_backend_role_secret_id" "redis" {
  backend   = vault_approle_auth_backend_role.redis.backend
  role_name = vault_approle_auth_backend_role.redis.role_name
}
