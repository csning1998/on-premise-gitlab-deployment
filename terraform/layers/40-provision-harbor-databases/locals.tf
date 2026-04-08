
# State Object
locals {
  state = {
    metadata  = data.terraform_remote_state.metadata.outputs
    network   = data.terraform_remote_state.network.outputs.infrastructure_map
    vault_pki = data.terraform_remote_state.vault_pki.outputs
    vault_sys = data.terraform_remote_state.vault_sys.outputs
    postgres  = data.terraform_remote_state.postgres.outputs
  }

  sys_vault_addr = "https://${local.state.vault_sys.service_vip}:443"
  minio_url      = "https://${data.terraform_remote_state.minio_infra.outputs.service_vip}:${data.terraform_remote_state.minio_infra.outputs.minio_api_port}"

  # Database Context (Aligned with GitLab structure)
  postgres_rw_port      = local.state.network["core-harbor-postgres"].lb_config.ports["rw-proxy"].frontend_port
  postgres_vip          = local.state.network["core-harbor-postgres"].lb_config.vip
  postgres_password     = data.vault_kv_secret_v2.db_vars.data["pg_superuser_password"]
  harbor_pg_db_password = data.vault_kv_secret_v2.harbor_vars.data["harbor_pg_db_password"]
}
