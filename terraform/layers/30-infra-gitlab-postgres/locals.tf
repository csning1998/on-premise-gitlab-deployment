
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
    replication_password = data.vault_kv_secret_v2.creds.data["pg_replication_password"]
    superuser_password   = data.vault_kv_secret_v2.creds.data["pg_superuser_password"]
    vrrp_secret          = data.vault_kv_secret_v2.creds.data["pg_vrrp_secret"]
  }

  sec_vault_agent_identity = merge(module.context.vault_agent_identity_base, {
    secret_id = vault_approle_auth_backend_role_secret_id.postgres_agent.secret_id
  })
}

# Ansible Configuration
locals {
  ansible_template_vars = {
    service_identifier    = module.context.svc_identity.cluster_name
    postgres_cluster_name = module.context.svc_identity.cluster_name

    postgres_ha_virtual_ip    = module.context.primary_net_config.lb_config.vip
    postgres_mtls_node_subnet = "${module.context.primary_net_config.network.hostonly.cidr} ${data.terraform_remote_state.network.outputs.infrastructure_map["core-gitlab-frontend"].network.hostonly.cidr}"
    vault_vip                 = module.context.vault_sys_vip
    global_mss                = module.context.global_mss

    postgres_static_route_to     = "${module.context.vault_sys_vip}/32"
    postgres_static_route_via    = module.context.primary_net_config.lb_config.vip
    postgres_static_route_metric = 100

    access_scope = module.context.primary_net_config.network.hostonly.cidr
    postgres_vip = module.context.primary_net_config.lb_config.vip
  }

  ansible_extra_vars = {
    pg_replication_password = local.sec_app_creds.replication_password
    pg_superuser_password   = local.sec_app_creds.superuser_password
    pg_vrrp_secret          = local.sec_app_creds.vrrp_secret
    vault_agent_common_name = local.sec_vault_agent_identity.common_name
    vault_agent_cert_ttl    = data.terraform_remote_state.vault_pki.outputs.pki_configuration.lease_durations.agent
  }
}
