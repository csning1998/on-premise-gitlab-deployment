
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

# Cross-layer dependency: Harbor registry PKI key is determined at runtime from bootstrapper state.
locals {
  registry_pki_key = data.terraform_remote_state.harbor_bootstrapper.outputs.pki_key
}

# Vault Agent identity
locals {
  sec_vault_agent_identity = merge(module.context.vault_agent_identity_base, {
    secret_id = vault_approle_auth_backend_role_secret_id.microk8s_agent.secret_id
  })
}

# Ansible Configuration
locals {
  ansible_template_vars = {
    service_identifier         = module.context.svc_identity.cluster_name
    microk8s_ingress_vip       = module.context.primary_net_config.lb_config.vip
    api_server_vip             = module.context.primary_net_config.lb_config.vip
    api_server_port            = module.context.svc_network.ports["api-server"].frontend_port
    microk8s_allowed_subnet    = module.context.primary_net_config.network.hostonly.cidr
    microk8s_nat_subnet_prefix = join(".", slice(split(".", module.context.primary_net_config.network.nat.gateway), 0, 3))
    global_mss                 = module.context.global_mss

    microk8s_static_routes = [
      for name, vip in data.terraform_remote_state.load_balancer.outputs.infrastructure_vips : {
        to     = "${vip}/32"
        via    = module.context.primary_net_config.lb_config.vip
        metric = 100
      }
      if contains([
        "vault-frontend", "keycloak-frontend",
        "harbor-bootstrapper-frontend",
        "harbor-postgres", "harbor-redis", "harbor-minio",
        "observability-frontend"
      ], name)
    ]

    microk8s_cluster_ips = [
      for node_suffix, node_data in var.service_config["frontend"].nodes :
      cidrhost(module.context.primary_net_config.network.hostonly.cidr, node_data.ip_suffix)
    ]

    registry_host       = data.terraform_remote_state.metadata.outputs.global_pki_map[local.registry_pki_key].dns_san[0]
    registry_vip        = data.terraform_remote_state.load_balancer.outputs.infrastructure_vips["harbor-bootstrapper-frontend"]
    harbor_docker_proxy = data.terraform_remote_state.harbor_proxy.outputs.proxy_caches["docker_hub"].project_name
    harbor_quay_proxy   = data.terraform_remote_state.harbor_proxy.outputs.proxy_caches["quay_io"].project_name
    harbor_k8s_proxy    = data.terraform_remote_state.harbor_proxy.outputs.proxy_caches["k8s_io"].project_name
  }

  ansible_extra_vars = {
    vault_ca_cert_b64       = local.sec_vault_agent_identity.ca_cert_b64
    vault_agent_role_id     = local.sec_vault_agent_identity.role_id
    vault_agent_secret_id   = local.sec_vault_agent_identity.secret_id
    vault_addr              = module.context.sys_vault_addr
    vault_role_name         = local.sec_vault_agent_identity.role_name
    vault_auth_path         = local.sec_vault_agent_identity.auth_path
    vault_agent_common_name = local.sec_vault_agent_identity.common_name
    vault_agent_cert_ttl    = data.terraform_remote_state.vault_pki.outputs.pki_configuration.lease_durations.agent
    service_name            = "harbor"
  }
}
