
# Call the Identity Module to generate AppRole & Secret ID
resource "vault_approle_auth_backend_role_secret_id" "redis_agent" {
  provider = vault.production
  # Path: local.state.vault_pki -> workload_identities_components -> harbor-redis
  backend   = local.state.vault_pki.workload_identities_components[local.sec_vault_role_key].auth_path
  role_name = local.state.vault_pki.workload_identities_components[local.sec_vault_role_key].role_name

  # Metadata for Vault Audit Log
  metadata = jsonencode({
    "source" = "terraform-layer-30-gitlab-redis"
  })
}
