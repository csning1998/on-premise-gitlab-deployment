
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_creds   = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_creds.username
    password = local._gl_creds.token
  }
}

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
  # Vault Address Calculation
  vault_api_port = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
  vault_address  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"

  # Postgres Discovery
  postgres_rw_port  = local.state.network["core-gitlab-postgres"].lb_config.ports["rw-proxy"].frontend_port
  postgres_vip      = local.state.network["core-gitlab-postgres"].lb_config.vip
  postgres_password = ephemeral.vault_kv_secret_v2.db_vars.data["pg_superuser_password"]

  # Minio Discovery
  minio_url = "https://${data.terraform_remote_state.minio.outputs.service_vip}:${data.terraform_remote_state.minio.outputs.minio_api_port}"
}

# Credential path map alias derived from foundation metadata (L00 SSoT)
locals {
  credential_paths = data.terraform_remote_state.metadata.outputs.global_credential_paths
}
