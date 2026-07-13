
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_creds   = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_creds.username
    password = local._gl_creds.token
  }
}

# 1. External State Context
locals {
  state = {
    vault_frontend         = data.terraform_remote_state.vault_frontend.outputs
    vault_pki              = data.terraform_remote_state.vault_pki.outputs
    vault_prod_bootstrap   = data.terraform_remote_state.vault_prod_bootstrap.outputs
    credentials            = data.terraform_remote_state.credentials.outputs
    observability_platform = data.terraform_remote_state.observability_platform.outputs
  }
}

# 2. Vault Provider Authentication Context
locals {
  vault_api_port = local.state.vault_frontend.vault_api_port
  vault_endpoint = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
}

# 3. Grafana, Mimir, and Loki Endpoint Context
locals {
  grafana_fqdn    = local.state.observability_platform.observability_endpoints.grafana_fqdn
  mimir_query_url = local.state.observability_platform.observability_endpoints.mimir_query_url
  loki_query_url  = local.state.observability_platform.observability_endpoints.loki_url
}

# 4. Credential Path Alias
locals {
  credential_paths = local.state.credentials.global_credential_paths
}
