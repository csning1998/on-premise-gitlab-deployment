
# State Object
locals {
  state = {
    metadata             = data.terraform_remote_state.metadata.outputs
    vault_sys            = data.terraform_remote_state.vault_sys.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
  }

  sys_vault_addr     = "https://${local.state.vault_sys.service_vip}:443"
  ca_cert_path       = local.state.vault_sys.ca_cert_path
  vault_kv_namespace = local.state.metadata.vault_kv_namespace
}
