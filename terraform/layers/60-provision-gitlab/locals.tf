
# 1. External State Context
locals {
  state = {
    metadata             = data.terraform_remote_state.metadata.outputs
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
  }
}

# 2. Vault Connection Context (For Provider)
locals {
  vault_address  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_api_port = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
}

# 3. GitLab Identity & Secrets (For Provider)
locals {
  gitlab_fqdn          = local.state.metadata.global_pki_map["gitlab-frontend"].dns_san[0]
  gitlab_root_password = data.vault_kv_secret_v2.gitlab_internal.data["root_password"]
}
