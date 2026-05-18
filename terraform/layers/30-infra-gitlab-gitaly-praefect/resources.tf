
# Call the Identity Module to generate AppRole & Secret ID for each component
resource "vault_approle_auth_backend_role_secret_id" "component_agents" {
  for_each = var.target_clusters
  provider = vault.production

  backend   = local.state.vault_pki.workload_identities_approle[local.state.metadata.global_pki_map[local.components_context[each.key].pki_key].key].auth_path
  role_name = local.state.vault_pki.workload_identities_approle[local.state.metadata.global_pki_map[local.components_context[each.key].pki_key].key].role_name

  # Metadata for Vault Audit Log
  metadata = jsonencode({
    "source"    = "terraform-layer-30-gitlab-gitaly-praefect"
    "component" = each.key
  })
}
