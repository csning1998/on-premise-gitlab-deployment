
resource "vault_approle_auth_backend_role_secret_id" "component_agents" {
  for_each = var.target_clusters
  provider = vault.production

  backend   = data.terraform_remote_state.vault_pki.outputs.workload_identities_approle[data.terraform_remote_state.metadata.outputs.global_pki_map[module.context.components_context[each.key].pki_key].key].auth_path
  role_name = data.terraform_remote_state.vault_pki.outputs.workload_identities_approle[data.terraform_remote_state.metadata.outputs.global_pki_map[module.context.components_context[each.key].pki_key].key].role_name

  metadata = jsonencode({
    "source"    = "terraform-layer-30-gitlab-gitaly-praefect"
    "component" = each.key
  })
}

