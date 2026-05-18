
output "auth_backend_path" {
  value = vault_jwt_auth_backend.keycloak.path
}

output "auth_backend_accessor" {
  value = vault_jwt_auth_backend.keycloak.accessor
}

output "oidc_role" {
  value = vault_jwt_auth_backend_role.keycloak_user.role_name
}

output "login_url" {
  value = "${local.vault_fqdn}/ui/vault/auth/oidc"
}
