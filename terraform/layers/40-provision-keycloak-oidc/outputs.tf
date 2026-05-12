
output "realm_id" {
  value = keycloak_realm.infra_realm.id
}

output "oidc_clients" {
  value = {
    for k, v in keycloak_openid_client.clients : k => {
      client_id   = v.client_id
      secret_path = vault_kv_secret_v2.oidc_clients[k].path
    }
  }
}

output "issuer_url" {
  value = "https://sso.keycloak.production.iac.internal/realms/${local.realm_id}"
}
