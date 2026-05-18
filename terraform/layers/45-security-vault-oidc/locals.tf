
locals {
  state = {
    metadata             = data.terraform_remote_state.metadata.outputs
    vault_sys            = data.terraform_remote_state.vault_sys.outputs
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    keycloak_oidc        = data.terraform_remote_state.keycloak_provisioning.outputs
  }

  vault_address = "https://${local.state.vault_sys.service_vip}:443"
  vault_fdqn    = "https://${local.state.metadata.global_pki_map["vault-frontend"].dns_san[0]}"

  # OIDC Configuration
  oidc_discovery_url = local.state.keycloak_oidc.issuer_url
  oidc_client_id     = data.vault_kv_secret_v2.keycloak_vault_client.data["client_id"]
  oidc_client_secret = data.vault_kv_secret_v2.keycloak_vault_client.data["client_secret"]
}
