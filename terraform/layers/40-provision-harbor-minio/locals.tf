
# State Object
locals {
  state = {
    vault_pki = data.terraform_remote_state.vault_pki.outputs
    vault_sys = data.terraform_remote_state.vault_sys.outputs
  }

  sys_vault_addr = "https://${local.state.vault_sys.service_vip}:443"
  minio_url      = "https://${data.terraform_remote_state.minio_infra.outputs.service_vip}:${data.terraform_remote_state.minio_infra.outputs.minio_api_port}"
}
