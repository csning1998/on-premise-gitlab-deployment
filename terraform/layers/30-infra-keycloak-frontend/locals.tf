
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_creds   = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_creds.username
    password = local._gl_creds.token
  }
}

# Provider prerequisites: Must be defined as root-level locals because provider blocks cannot reference module outputs.
locals {
  sys_vault_endpoint  = "https://${data.terraform_remote_state.vault_pki.outputs.vault_service_vip}:443"
  vault_pki_cert_path = data.terraform_remote_state.vault_pki.outputs.bootstrap_ca_b64.path
}

# Credential path map alias passed through from L25 security-pki
locals {
  credential_paths = data.terraform_remote_state.vault_pki.outputs.global_credential_paths
}

# Service-specific credentials and Vault Agent identity
locals {
  sec_app_creds = {
    keycloak_admin_user     = data.vault_kv_secret_v2.creds.data["keycloak_admin_user"]
    keycloak_admin_password = data.vault_kv_secret_v2.creds.data["keycloak_admin_password"]
    keycloak_db_user        = data.vault_kv_secret_v2.creds.data["keycloak_db_user"]
    keycloak_db_password    = data.vault_kv_secret_v2.creds.data["keycloak_db_password"]
  }

  sec_vault_agent_identity = merge(module.context.vault_agent_identity_base, {
    secret_id = vault_approle_auth_backend_role_secret_id.keycloak_agent.secret_id
  })
}

# Ansible Configuration
locals {
  ansible_template_vars = {
    service_identifier      = module.context.primary_context.s_name
    keycloak_fqdn           = module.context.svc_fqdn
    keycloak_service_domain = module.context.svc_identity.cluster_name

    keycloak_vip         = module.context.primary_net_config.lb_config.vip
    keycloak_port        = module.context.primary_net_config.lb_config.ports["https"].frontend_port
    keycloak_node_subnet = module.context.primary_net_config.network.hostonly.cidr
    vault_vip            = module.context.vault_sys_vip
    global_mss           = module.context.global_mss

    keycloak_cluster_ips = [
      for comp_name, comp_config in var.service_config : [
        for node_suffix, node_data in comp_config.nodes :
        cidrhost(module.context.primary_net_config.network.hostonly.cidr, node_data.ip_suffix)
      ]
    ][0]

    keycloak_static_routes = [
      for name, vip in data.terraform_remote_state.load_balancer.outputs.infrastructure_vips : {
        to     = "${vip}/32"
        via    = module.context.primary_net_config.lb_config.vip
        metric = 100
      }
      if contains(["vault-frontend"], name)
    ]

    access_scope = module.context.primary_net_config.network.hostonly.cidr
    service_name = module.context.primary_context.s_name
  }

  ansible_extra_vars = {
    keycloak_admin_user     = local.sec_app_creds.keycloak_admin_user
    keycloak_admin_password = local.sec_app_creds.keycloak_admin_password
    keycloak_db_user        = local.sec_app_creds.keycloak_db_user
    keycloak_db_password    = local.sec_app_creds.keycloak_db_password
    vault_agent_common_name = local.sec_vault_agent_identity.common_name
    vault_agent_cert_ttl    = data.terraform_remote_state.vault_pki.outputs.pki_configuration.lease_durations.agent
  }
}
