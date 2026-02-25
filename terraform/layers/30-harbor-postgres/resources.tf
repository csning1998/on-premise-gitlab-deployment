
# Call the Identity Module to generate AppRole & Secret ID
resource "vault_approle_auth_backend_role_secret_id" "postgres_agent" {
  # Path: local.state.vault_pki -> workload_identities_dependencies -> harbor-postgres-dep
  backend   = local.state.vault_pki.workload_identities_dependencies[local.sec_vault_identity_key].auth_path
  role_name = local.state.vault_pki.workload_identities_dependencies[local.sec_vault_identity_key].role_name

  # Metadata for Vault Audit Log
  metadata = jsonencode({
    "source" = "terraform-layer-30-harbor-postgres"
  })
}
