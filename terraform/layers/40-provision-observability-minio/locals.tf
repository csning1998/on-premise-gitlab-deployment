
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
    vault_frontend       = data.terraform_remote_state.vault_frontend.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    minio                = data.terraform_remote_state.minio.outputs
  }
}

locals {
  # Vault Address Calculation
  vault_api_port = local.state.vault_frontend.vault_api_port
  vault_endpoint = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"

  # MinIO Discovery
  minio_url = "https://${data.terraform_remote_state.minio.outputs.service_vip}:${data.terraform_remote_state.minio.outputs.minio_api_port}"
}

# Credential path map alias passed through from L25 security-pki
locals {
  credential_paths = data.terraform_remote_state.vault_pki.outputs.global_credential_paths
}
