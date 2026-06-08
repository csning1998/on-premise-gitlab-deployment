
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_creds   = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_creds.username
    password = local._gl_creds.token
  }
}

# Provider prerequisites — must remain root-level locals; provider blocks cannot reference module outputs.
locals {
  sys_vault_addr      = "https://${data.terraform_remote_state.vault_sys.outputs.service_vip}:443"
  vault_pki_cert_path = data.terraform_remote_state.vault_pki.outputs.bootstrap_ca_b64.path
}

# Credential path map alias derived from foundation metadata (L00 SSoT)
locals {
  credential_paths = data.terraform_remote_state.metadata.outputs.global_credential_paths
}

# Service-specific credentials and Vault Agent identity
locals {
  sec_app_creds = {
    harbor_admin_password = data.vault_kv_secret_v2.creds.data["harbor_bootstrapper_admin_password"]
    harbor_pg_db_password = data.vault_kv_secret_v2.creds.data["harbor_bootstrapper_pg_db_password"]
  }

  sec_vault_agent_identity = merge(module.context.vault_agent_identity_base, {
    secret_id = vault_approle_auth_backend_role_secret_id.bootstrap_harbor_agent.secret_id
  })
}

# Ansible Configuration
locals {
  ansible_template_vars = {
    service_identifier           = module.context.primary_context.s_name
    bstrap_harbor_fqdn           = module.context.svc_fqdn
    bstrap_harbor_service_domain = module.context.svc_identity.cluster_name

    bstrap_harbor_vip              = module.context.primary_net_config.lb_config.vip
    bstrap_harbor_tls_port         = module.context.primary_net_config.lb_config.ports["https"].frontend_port
    bstrap_harbor_mtls_node_subnet = module.context.primary_net_config.network.hostonly.cidr
    vault_vip                      = data.terraform_remote_state.load_balancer.outputs.infrastructure_vips["vault-frontend"]
    global_mss                     = module.context.global_mss

    bstrap_harbor_cluster_ips = [
      for comp_name, comp_config in var.service_config : [
        for node_suffix, node_data in comp_config.nodes :
        cidrhost(module.context.primary_net_config.network.hostonly.cidr, node_data.ip_suffix)
      ]
    ][0]

    bstrap_harbor_static_routes = [
      for name, vip in data.terraform_remote_state.load_balancer.outputs.infrastructure_vips : {
        to     = "${vip}/32"
        via    = module.context.primary_net_config.lb_config.vip
        metric = 100
      }
      if contains([
        "vault-frontend", "keycloak-frontend",
        "harbor-bootstrapper-frontend"
      ], name)
    ]

    access_scope = module.context.primary_net_config.network.hostonly.cidr
    service_name = module.context.primary_context.s_name
  }

  ansible_extra_vars = {
    harbor_bootstrapper_admin_password = local.sec_app_creds.harbor_admin_password
    harbor_bootstrapper_pg_db_password = local.sec_app_creds.harbor_pg_db_password
    vault_agent_common_name            = local.sec_vault_agent_identity.common_name
    vault_agent_cert_ttl               = data.terraform_remote_state.vault_pki.outputs.pki_configuration.lease_durations.agent
  }
}
