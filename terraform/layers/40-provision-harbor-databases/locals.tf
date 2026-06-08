
# State Object
locals {
  state = {
    metadata             = data.terraform_remote_state.metadata.outputs
    network              = data.terraform_remote_state.network.outputs.infrastructure_map
    vault_sys            = data.terraform_remote_state.vault_sys.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    postgres             = data.terraform_remote_state.postgres.outputs
    redis                = data.terraform_remote_state.redis.outputs
    minio                = data.terraform_remote_state.minio.outputs
  }
}

locals {
  credential_paths = data.terraform_remote_state.metadata.outputs.global_credential_paths

  # Vault Address Calculation
  vault_api_port = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
  vault_address  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"

  # Database Context (Aligned with GitLab structure)
  postgres_rw_port  = local.state.network["core-harbor-postgres"].lb_config.ports["rw-proxy"].frontend_port
  postgres_vip      = local.state.network["core-harbor-postgres"].lb_config.vip
  postgres_password = ephemeral.vault_kv_secret_v2.db_vars.data["pg_superuser_password"]

  # Minio Discovery
  minio_url = "https://${local.state.minio.service_vip}:${local.state.minio.minio_api_port}"
}
