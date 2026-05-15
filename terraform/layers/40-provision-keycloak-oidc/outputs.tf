output "issuer_url" {
  value = "${local.keycloak_frontend_url}/realms/${local.realm_id}"
}

output "oidc_clients" {
  value     = keycloak_openid_client.clients
  sensitive = true
}

output "vault_redirect_uris" {
  value = local.vault_redirect_uris
}
