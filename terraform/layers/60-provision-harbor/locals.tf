
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

# 3. Harbor Identity & Secrets (For Provider)
locals {
  harbor_hostname       = local.state.metadata.global_pki_map["harbor-frontend"].dns_san[0]
  harbor_admin_password = data.vault_kv_secret_v2.harbor_vars.data["harbor_admin_password"]
}
