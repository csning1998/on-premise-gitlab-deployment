
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_credentials = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base     = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_credentials.username
    password = local._gl_credentials.token
  }
}

locals {
  bootstrap_ca_chain_pem = "${data.terraform_remote_state.vault_bootstrapper.outputs.bootstrap_root_ca_certificate_pem}\n${data.terraform_remote_state.vault_bootstrapper.outputs.bootstrap_intermediate_ca_certificate_pem}"

  ansible_template_config = {
    global_mss          = module.context.global_mss
    vault_vip           = module.context.primary_net_config.lb_config.vip
    vault_cluster_name  = module.context.svc_identity.cluster_name
    vault_static_routes = one(values(module.context.asymmetric_static_routes))
  }

  ansible_extra_config = {
    ansible_user          = module.context.sec_vm_credentials.username
    dev_vault_url         = var.vault_dev_endpoint
    dev_vault_api_path    = "on-premise-gitlab-deployment/credentials"
    vault_server_cert_b64 = base64encode(vault_pki_secret_backend_cert.vault_listener.certificate)
    vault_server_key_b64  = base64encode(vault_pki_secret_backend_cert.vault_listener.private_key)
    vault_ca_cert_b64     = base64encode(local.bootstrap_ca_chain_pem)
  }
}
