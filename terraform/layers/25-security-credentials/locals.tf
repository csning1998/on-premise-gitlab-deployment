
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_credentials = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base     = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_credentials.username
    password = local._gl_credentials.token
  }
}

# State Object
locals {
  state = {
    metadata             = data.terraform_remote_state.metadata.outputs
    vault_sys            = data.terraform_remote_state.vault_sys.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
  }

  sys_vault_endpoint = "https://${local.state.vault_sys.service_vip}:443"
  ca_cert_path       = local.state.vault_sys.ca_cert_path
  vault_kv_namespace = local.state.metadata.vault_kv_namespace
}
