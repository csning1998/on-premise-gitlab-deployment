
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_creds   = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_creds.username
    password = local._gl_creds.token
  }
}

locals {
  ansible_template_vars = {
    global_mss          = module.context.global_mss
    vault_vip           = module.context.primary_net_config.lb_config.vip
    vault_cluster_name  = module.context.svc_identity.cluster_name
    vault_static_routes = one(values(module.context.asymmetric_static_routes))
  }

  ansible_extra_vars = merge(
    {
      ansible_user       = module.context.sec_vm_creds.username
      dev_vault_url      = var.vault_dev_addr
      dev_vault_api_path = "on-premise-gitlab-deployment/credentials"
    },
    module.context.global_vault_pki_b64 != null ? {
      vault_server_cert_b64 = module.context.global_vault_pki_b64.server_cert_b64
      vault_server_key_b64  = module.context.global_vault_pki_b64.server_key_b64
      vault_ca_cert_b64     = module.context.global_vault_pki_b64.ca_cert_b64
    } : {}
  )
}
