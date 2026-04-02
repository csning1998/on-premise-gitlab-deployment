
locals {
  state = {
    metadata            = data.terraform_remote_state.metadata.outputs
    vault_pki           = data.terraform_remote_state.vault_pki.outputs
    network             = data.terraform_remote_state.network.outputs.infrastructure_map
    postgres            = data.terraform_remote_state.postgres.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
  }

  # Vault Address Calculation
  vault_api_port = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
  vault_address  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"

  # Postgres Discovery
  postgres_rw_port = local.state.network["core-gitlab-postgres"].lb_config.ports["rw-proxy"].frontend_port
  postgres_vip     = local.state.network["core-gitlab-postgres"].lb_config.vip
  postgres_password = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
}
