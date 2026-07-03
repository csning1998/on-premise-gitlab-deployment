
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
    network              = data.terraform_remote_state.network.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
  }
}

locals {
  # Vault Address Calculation
  vault_api_port = local.state.network.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
  vault_address  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"

  # Postgres Discovery
  postgres_rw_port  = local.state.network.infrastructure_map["core-gitlab-postgres"].lb_config.ports["rw-proxy"].frontend_port
  postgres_vip      = local.state.network.infrastructure_map["core-gitlab-postgres"].lb_config.vip
  postgres_password = ephemeral.vault_kv_secret_v2.db_vars.data["pg_superuser_password"]

  # Minio Discovery
  minio_url = "https://${local.state.network.infrastructure_map["core-gitlab-minio"].lb_config.vip}:${local.state.network.infrastructure_map["core-gitlab-minio"].lb_config.ports["api"].frontend_port}"
}

# Credential path map alias passed through from L25 security-pki
locals {
  credential_paths = data.terraform_remote_state.vault_pki.outputs.global_credential_paths
}
