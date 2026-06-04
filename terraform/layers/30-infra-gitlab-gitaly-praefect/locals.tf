
# Provider prerequisites — must remain root-level locals; provider blocks cannot reference module outputs.
locals {
  sys_vault_addr      = "https://${data.terraform_remote_state.vault_sys.outputs.service_vip}:443"
  vault_pki_cert_path = data.terraform_remote_state.vault_pki.outputs.bootstrap_ca_b64.path
}

# Service credentials and per-role Vault Agent identities
locals {
  sec_app_creds = {
    replication_password = data.vault_generic_secret.db_vars.data["pg_replication_password"]
    superuser_password   = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
    vrrp_secret          = data.vault_generic_secret.db_vars.data["pg_vrrp_secret"]
  }

  role_vault_agent_identities = {
    for role, base in module.context.all_vault_agent_identity_bases : role => merge(base, {
      secret_id = vault_approle_auth_backend_role_secret_id.component_agents[role].secret_id
    })
  }

  sec_vault_agent_identity = local.role_vault_agent_identities[var.primary_role]
}

# Ansible Configuration
locals {
  ansible_template_vars = {
    service_identifier    = module.context.svc_identity.cluster_name
    postgres_cluster_name = lookup(var.target_clusters, "praefect-patroni", "") != "" ? var.target_clusters["praefect-patroni"] : ""

    postgres_ha_virtual_ip = module.context.network_infrastructure_map["praefect-patroni"].lb_config.vip
    postgres_mtls_node_subnet = join(" ", compact([
      module.context.network_infrastructure_map["praefect-patroni"].network.hostonly.cidr,
      module.context.network_infrastructure_map["praefect"].network.hostonly.cidr,
      data.terraform_remote_state.network.outputs.infrastructure_map["core-gitlab-frontend"].network.hostonly.cidr,
    ]))
    vault_vip  = module.context.vault_sys_vip
    global_mss = module.context.global_mss

    gitaly_ha_virtual_ip   = module.context.network_infrastructure_map["gitaly"].lb_config.vip
    praefect_ha_virtual_ip = module.context.network_infrastructure_map["praefect"].lb_config.vip
    gitlab_frontend_vip    = data.terraform_remote_state.network.outputs.infrastructure_map["core-gitlab-frontend"].lb_config.vip

    gitaly_static_routes = [
      for name, vip in data.terraform_remote_state.network.outputs.infrastructure_vips : {
        to     = "${vip}/32"
        via    = module.context.network_infrastructure_map["gitaly"].lb_config.vip
        metric = 100
      }
      if contains(["vault-frontend", "gitlab-frontend", "gitlab-praefect"], name)
    ]

    praefect_static_routes = [
      for name, vip in data.terraform_remote_state.network.outputs.infrastructure_vips : {
        to     = "${vip}/32"
        via    = module.context.network_infrastructure_map["praefect"].lb_config.vip
        metric = 100
      }
      if contains(["vault-frontend", "gitlab-frontend", "gitlab-gitaly", "gitlab-praefect-patroni"], name)
    ]

    postgres_static_routes = [
      for name, vip in data.terraform_remote_state.network.outputs.infrastructure_vips : {
        to     = "${vip}/32"
        via    = module.context.network_infrastructure_map["praefect-patroni"].lb_config.vip
        metric = 100
      }
      if contains(["vault-frontend", "gitlab-praefect"], name)
    ]

    postgres_vault_role_key = "praefect-patroni"
  }

  ansible_extra_vars = {
    gitlab_external_url     = "https://${data.terraform_remote_state.metadata.outputs.global_pki_map["gitlab-frontend"].dns_san[0]}"
    gitlab_shell_secret     = random_password.gitlab_shell_secret.result
    gitaly_auth_token       = random_password.gitaly_token.result
    praefect_external_token = one(random_password.praefect_external_token[*].result)
    praefect_db_password    = one(random_password.praefect_db_password[*].result)
    pg_replication_password = random_password.pg_replication_password.result
    pg_superuser_password   = random_password.pg_superuser_password.result
    pg_vrrp_secret          = random_password.pg_vrrp_secret.result
    vault_agent_cert_ttl    = tostring(data.terraform_remote_state.vault_pki.outputs.pki_configuration.lease_durations.agent)

    vault_agent_identities_json = base64encode(jsonencode({
      for role, id in local.role_vault_agent_identities : role => {
        vault_addr  = id.vault_address
        role_id     = id.role_id
        secret_id   = id.secret_id
        role_name   = id.role_name
        auth_path   = id.auth_path
        common_name = id.common_name
      }
    }))
  }
}
