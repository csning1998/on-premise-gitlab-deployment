
# Call the Identity Module to generate AppRole & Secret ID
resource "vault_approle_auth_backend_role_secret_id" "microk8s_agent" {
  # Path: local.state.vault_pki -> workload_identities_components -> harbor-frontend
  backend   = local.state.vault_pki.workload_identities_components[local.sec_vault_identity_key].auth_path
  role_name = local.state.vault_pki.workload_identities_components[local.sec_vault_identity_key].role_name

  # Metadata for Vault Audit Log
  metadata = jsonencode({
    "source" = "terraform-layer-40-harbor-microk8s"
  })
}
