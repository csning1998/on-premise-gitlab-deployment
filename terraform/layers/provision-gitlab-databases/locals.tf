
# The remote state reads take TF_HTTP_USERNAME and TF_HTTP_PASSWORD from the environment, which vault-proxy-env exports.
locals {
  _state_base = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
}

# State Object
locals {
  state = {
    vault_frontend       = data.terraform_remote_state.vault_frontend.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    postgres             = data.terraform_remote_state.postgres.outputs
    redis                = data.terraform_remote_state.redis.outputs
    minio                = data.terraform_remote_state.minio.outputs
  }
}

locals {
  # Vault Address Calculation
  vault_api_port = local.state.vault_frontend.vault_api_port
  vault_endpoint = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"

  # Postgres Discovery
  postgres_rw_port  = local.state.postgres.connection_info.port
  postgres_vip      = local.state.postgres.connection_info.host
  postgres_password = ephemeral.vault_kv_secret_v2.db_vars.data["pg_superuser_password"]

  # Minio Discovery
  minio_url = "https://${local.state.minio.connection_info.host}:${local.state.minio.connection_info.port}"
}

# Credential path map alias passed through from security-pki
locals {
  credential_paths = data.terraform_remote_state.vault_pki.outputs.global_credential_paths
}
