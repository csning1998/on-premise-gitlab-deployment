
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
    masterauth  = data.vault_kv_secret_v2.creds.data["redis_masterauth"]
    requirepass = data.vault_kv_secret_v2.creds.data["redis_requirepass"]
    vrrp_secret = data.vault_kv_secret_v2.creds.data["redis_vrrp_secret"]
  }

  sec_vault_agent_identity = merge(module.context.vault_agent_identity_base, {
    secret_id = vault_approle_auth_backend_role_secret_id.redis_agent.secret_id
  })
}

# Ansible Configuration
locals {
  ansible_template_vars = {
    service_identifier   = module.context.svc_identity.cluster_name
    redis_service_domain = module.context.svc_fqdn

    redis_ha_virtual_ip   = module.context.primary_net_config.lb_config.vip
    redis_tls_node_subnet = module.context.primary_net_config.network.hostonly.cidr
    redis_tls_port        = module.context.primary_net_config.lb_config.ports["main"].frontend_port
    vault_vip             = module.context.vault_sys_vip
    global_mss            = module.context.global_mss

    redis_cluster_ips = join(",", [
      for node_suffix, node_data in var.service_config["redis"].nodes :
      cidrhost(module.context.primary_net_config.network.hostonly.cidr, node_data.ip_suffix)
    ])
    redis_initial_master_ip = cidrhost(module.context.primary_net_config.network.hostonly.cidr, var.service_config["redis"].nodes["00"].ip_suffix)
    sentinel_quorum         = floor(length(var.service_config["redis"].nodes) / 2) + 1

    redis_static_route_to     = "${module.context.vault_sys_vip}/32"
    redis_static_route_via    = module.context.primary_net_config.lb_config.vip
    redis_static_route_metric = 100

    access_scope = module.context.primary_net_config.network.hostonly.cidr
    redis_vip    = module.context.primary_net_config.lb_config.vip
    cluster_name = module.context.svc_identity.cluster_name
  }

  ansible_extra_vars = {
    redis_masterauth        = local.sec_app_creds.masterauth
    redis_requirepass       = local.sec_app_creds.requirepass
    redis_vrrp_secret       = local.sec_app_creds.vrrp_secret
    vault_agent_common_name = local.sec_vault_agent_identity.common_name
    vault_agent_cert_ttl    = data.terraform_remote_state.vault_pki.outputs.pki_configuration.lease_durations.agent
  }
}
