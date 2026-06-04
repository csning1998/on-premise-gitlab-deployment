
# Provider prerequisites — must remain root-level locals; provider blocks cannot reference module outputs.
locals {
  sys_vault_addr      = "https://${data.terraform_remote_state.vault_sys.outputs.service_vip}:443"
  vault_pki_cert_path = data.terraform_remote_state.vault_pki.outputs.bootstrap_ca_b64.path
}

# Service-specific credentials and Vault Agent identity
locals {
  sec_db_creds = {
    minio_root_user     = data.vault_generic_secret.db_vars.data["minio_root_user"]
    minio_root_password = data.vault_generic_secret.db_vars.data["minio_root_password"]
    minio_vrrp_secret   = data.vault_generic_secret.db_vars.data["minio_vrrp_secret"]
  }

  sec_vault_agent_identity = merge(module.context.vault_agent_identity_base, {
    secret_id = vault_approle_auth_backend_role_secret_id.minio_agent.secret_id
  })
}

# Ansible Configuration
locals {
  ansible_template_vars = {
    service_identifier   = module.context.svc_identity.cluster_name
    minio_cluster_name   = "${module.context.svc_identity.cluster_name}-minio-cluster"
    minio_service_domain = module.context.svc_fqdn

    minio_ha_virtual_ip         = module.context.primary_net_config.lb_config.vip
    minio_tls_node_subnet       = module.context.primary_net_config.network.hostonly.cidr
    minio_nat_subnet_prefix     = join(".", slice(split(".", module.context.primary_net_config.network.nat.gateway), 0, 3))
    minio_frontend_port_api     = module.context.primary_net_config.lb_config.ports["api"].frontend_port
    minio_frontend_port_console = module.context.primary_net_config.lb_config.ports["console"].frontend_port
    vault_vip                   = module.context.vault_sys_vip
    global_mss                  = module.context.global_mss

    minio_cluster_ips = [
      for node_suffix, node_data in var.service_config["minio"].nodes :
      cidrhost(module.context.primary_net_config.network.hostonly.cidr, node_data.ip_suffix)
    ]

    minio_static_route_to     = "${module.context.vault_sys_vip}/32"
    minio_static_route_via    = module.context.primary_net_config.lb_config.vip
    minio_static_route_metric = 100

    access_scope = module.context.primary_net_config.network.hostonly.cidr
    minio_vip    = module.context.primary_net_config.lb_config.vip
  }

  ansible_extra_vars = {
    minio_root_user         = local.sec_db_creds.minio_root_user
    minio_root_password     = local.sec_db_creds.minio_root_password
    minio_vrrp_secret       = local.sec_db_creds.minio_vrrp_secret
    vault_agent_common_name = local.sec_vault_agent_identity.common_name
    vault_agent_cert_ttl    = data.terraform_remote_state.vault_pki.outputs.pki_configuration.lease_durations.agent
  }
}
