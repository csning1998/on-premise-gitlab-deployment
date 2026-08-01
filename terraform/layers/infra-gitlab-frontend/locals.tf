
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_credentials = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base     = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_credentials.username
    password = local._gl_credentials.token
  }
}

# Provider prerequisites: Must be defined as root-level locals because provider blocks cannot reference module outputs.
locals {
  sys_vault_endpoint  = "https://${data.terraform_remote_state.vault_pki.outputs.vault_service_vip}:443"
  vault_pki_cert_path = data.terraform_remote_state.vault_pki.outputs.bootstrap_ca_b64.path
}

# Since Kubeadm requires role-differentiated node name prefixes (master/worker), the provision module
# can generate distinct node names such as core-gitlab-frontend-master-00 and -worker-10.
locals {
  kubeadm_node_identities = {
    for role, identity in module.context.node_identities : role => merge(identity, {
      node_name_prefix = "${identity.cluster_name}-${role}"
    })
  }
}

# Vault Agent identity
locals {
  sec_vault_agent_identity = merge(module.context.vault_agent_identity_base, {
    secret_id = vault_approle_auth_backend_role_secret_id.kubeadm_agent.secret_id
  })
}

# Cross-layer dependency: Harbor registry PKI key is determined at runtime from bootstrapper state.
locals {
  registry_pki_key = data.terraform_remote_state.harbor_bootstrapper.outputs.pki_key
}

# Ansible Configuration
locals {
  ansible_template_config = {
    service_identifier = "${module.context.svc_identity.cluster_name}-kubeadm-cluster"

    kubeadm_master_nodes = var.service_config["master"].nodes
    kubeadm_worker_nodes = var.service_config["worker"].nodes

    kubeadm_master_ips = [
      for node_suffix, node_data in var.service_config["master"].nodes :
      cidrhost(module.context.primary_net_config.network.hostonly.cidr, node_data.ip_suffix)
    ]
    kubeadm_ha_vip            = module.context.primary_net_config.lb_config.vip
    kubeadm_pod_subnet        = var.kubernetes_cluster_configuration.pod_subnet
    kubeadm_nat_subnet_prefix = join(".", slice(split(".", module.context.primary_net_config.network.nat.gateway), 0, 3))
    global_mss                = module.context.global_mss

    kubeadm_registry_host        = data.terraform_remote_state.vault_pki.outputs.global_pki_map[local.registry_pki_key].dns_san[0]
    kubeadm_registry_vip         = data.terraform_remote_state.load_balancer.outputs.infrastructure_vips["harbor-bootstrapper-frontend"]
    kubeadm_image_repository     = "${data.terraform_remote_state.load_balancer.outputs.infrastructure_vips["harbor-bootstrapper-frontend"]}/${data.terraform_remote_state.harbor_proxy.outputs.proxy_caches["k8s_io"].project_name}"
    kubeadm_dns_image_repository = "${data.terraform_remote_state.load_balancer.outputs.infrastructure_vips["harbor-bootstrapper-frontend"]}/${data.terraform_remote_state.harbor_proxy.outputs.proxy_caches["k8s_io"].project_name}/coredns"

    kubeadm_http_nodeport  = module.context.primary_net_config.lb_config.ports["ingress-http"].backend_port
    kubeadm_https_nodeport = module.context.primary_net_config.lb_config.ports["ingress-https"].backend_port

    harbor_docker_proxy = data.terraform_remote_state.harbor_proxy.outputs.proxy_caches["docker_hub"].project_name
    harbor_quay_proxy   = data.terraform_remote_state.harbor_proxy.outputs.proxy_caches["quay_io"].project_name
    harbor_k8s_proxy    = data.terraform_remote_state.harbor_proxy.outputs.proxy_caches["k8s_io"].project_name

    kubeadm_static_routes = [
      for name, vip in data.terraform_remote_state.load_balancer.outputs.infrastructure_vips : {
        to     = "${vip}/32"
        via    = module.context.primary_net_config.lb_config.vip
        metric = 100
      }
      if contains([
        "vault-frontend", "keycloak-frontend",
        "harbor-bootstrapper-frontend", "harbor-frontend",
        "gitlab-postgres", "gitlab-redis", "gitlab-minio", "gitlab-gitaly", "gitlab-praefect",
        "observability-frontend"
      ], name)
    ]

    vip        = module.context.primary_net_config.lb_config.vip
    pod_subnet = var.kubernetes_cluster_configuration.pod_subnet
  }

  ansible_extra_config = {
    vault_ca_cert_b64       = local.sec_vault_agent_identity.ca_cert_b64
    vault_agent_role_id     = local.sec_vault_agent_identity.role_id
    vault_agent_secret_id   = local.sec_vault_agent_identity.secret_id
    vault_endpoint          = module.context.sys_vault_endpoint
    vault_role_name         = local.sec_vault_agent_identity.role_name
    vault_auth_path         = local.sec_vault_agent_identity.auth_path
    vault_agent_common_name = local.sec_vault_agent_identity.common_name
    vault_agent_cert_ttl    = data.terraform_remote_state.vault_pki.outputs.pki_configuration.lease_durations.agent
    service_name            = module.context.primary_context.s_name
  }
}
