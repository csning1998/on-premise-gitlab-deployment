
# 1. State Hub (Cross-Layer SSoT)
locals {
  state = {
    metadata        = data.terraform_remote_state.metadata.outputs
    volume          = data.terraform_remote_state.volume.outputs
    network         = data.terraform_remote_state.network.outputs
    vault_sys       = data.terraform_remote_state.vault_sys.outputs
    vault_pki       = data.terraform_remote_state.vault_pki.outputs
    harbor_registry = data.terraform_remote_state.harbor_bootstrapper.outputs
    harbor_proxy    = data.terraform_remote_state.harbor_proxy.outputs
  }
}

# 2. Unified SSoT Alignment (Zero-Hardcode Discovery)
locals {
  # Zip all identities and networks across all services into an O(1) lookup map indexed by cluster_name
  segments_map = merge([
    for s_name, components in local.state.metadata.global_topology_identity : {
      for c_name, identity in components : identity.cluster_name => {
        identity = identity
        network  = local.state.metadata.global_topology_network[s_name][c_name]
        pki_key  = "${s_name}-${c_name}"
        s_name   = s_name
        c_name   = c_name
      }
    }
  ]...)

  # Resolve all targeted roles into a components context map using physical cluster names from tfvars
  components_context = {
    for role, cluster_name in var.target_clusters : role => local.segments_map[cluster_name]
  }

  # Primary component definitions
  primary_context = local.components_context[var.primary_role]
  svc_identity    = local.primary_context.identity

  # PKI Role Context
  svc_pki_role = local.state.metadata.global_pki_map[local.primary_context.pki_key]
  svc_fqdn     = local.svc_pki_role.dns_san[0]
}

# 3. Network & Performance Context (net_)
locals {
  # Build flattened map of network segments keyed by network_tier for the module
  network_infrastructure_map = {
    for role, ctx in local.components_context : var.service_config[role].network_tier => local.state.network.infrastructure_map[ctx.identity.cluster_name]...
  }

  network_infrastructure_map_flat = { for k, v in local.network_infrastructure_map : k => v[0] }

  # Canonical Network Config (from Primary Entrypoint)
  p_net_config = local.state.network.infrastructure_map[local.svc_identity.cluster_name]
}

# 4. Security & Credentials Context (sec_ / pki_)
locals {
  sys_vault_addr = "https://${local.state.vault_sys.service_vip}:443"

  # System Level Credentials (OS/SSH)
  sec_vm_creds = {
    username             = data.vault_generic_secret.guest_vm.data["vm_username"]
    password             = data.vault_generic_secret.guest_vm.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.guest_vm.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.guest_vm.data["ssh_private_key_path"]
  }

  # Vault Agent Physical Identity (Mapped to Component PKI)
  sec_vault_identity_key = local.svc_pki_role.key

  sec_vault_agent_identity = {
    vault_address = local.sys_vault_addr
    auth_path     = local.state.vault_pki.workload_identities_approle[local.sec_vault_identity_key].auth_path
    role_id       = local.state.vault_pki.workload_identities_approle[local.sec_vault_identity_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.pki_roles[local.sec_vault_identity_key].name
    secret_id     = vault_approle_auth_backend_role_secret_id.kubeadm_agent.secret_id
    ca_cert_b64   = local.state.vault_pki.bootstrap_ca_b64.content_b64
    common_name   = local.svc_fqdn
  }

  # Role-Based Node Identities with Module-Compliant Naming Prefix
  # This aligns with the underlying ha-service-kvm-general expectations.
  node_identities = {
    for role, ctx in local.components_context : role => merge(ctx.identity, {
      node_name_prefix = "${ctx.identity.cluster_name}-${role}"
    })
  }
}

# 5. Topology Component Construction
locals {
  topology_cluster = {
    storage_pool_name = local.svc_identity.storage_pool_name
    components        = var.service_config
  }
}

# 6. Ansible Configuration (Dynamic Inventory)
locals {
  # Dependency discovery: Use the physical SSoT key for the Harbor registry.
  registry_pki_key = local.state.harbor_registry.pki_key

  ansible_template_vars = {
    # Service Identifiers
    service_identifier = "${local.svc_identity.cluster_name}-kubeadm-cluster"

    # Cluster Topology (Master/Worker Maps)
    kubeadm_master_nodes = var.service_config["master"].nodes
    kubeadm_worker_nodes = var.service_config["worker"].nodes

    # Networking & HA
    kubeadm_master_ips = [
      for node_suffix, node_data in var.service_config["master"].nodes :
      cidrhost(local.p_net_config.network.hostonly.cidr, node_data.ip_suffix)
    ]
    kubeadm_ha_virtual_ip     = local.p_net_config.lb_config.vip
    kubeadm_pod_subnet        = var.kubernetes_cluster_configuration.pod_subnet
    kubeadm_nat_subnet_prefix = join(".", slice(split(".", local.p_net_config.network.nat.gateway), 0, 3))
    global_mss                = local.state.metadata.global_network_baseline.global_mss

    # Registry & Image Config
    kubeadm_registry_host        = local.state.metadata.global_pki_map[local.registry_pki_key].dns_san[0]
    kubeadm_registry_vip         = local.state.network.infrastructure_vips["harbor-bootstrapper-frontend"]
    kubeadm_image_repository     = "${local.state.network.infrastructure_vips["harbor-bootstrapper-frontend"]}/${local.state.harbor_proxy.proxy_caches["k8s_io"].project_name}"
    kubeadm_dns_image_repository = "${local.state.network.infrastructure_vips["harbor-bootstrapper-frontend"]}/${local.state.harbor_proxy.proxy_caches["k8s_io"].project_name}/coredns"

    # Port Mappings
    kubeadm_http_nodeport  = local.p_net_config.lb_config.ports["ingress-http"].backend_port
    kubeadm_https_nodeport = local.p_net_config.lb_config.ports["ingress-https"].backend_port

    # Mirroring Paths (Template Compatibility)
    harbor_docker_proxy = local.state.harbor_proxy.proxy_caches["docker_hub"].project_name
    harbor_quay_proxy   = local.state.harbor_proxy.proxy_caches["quay_io"].project_name
    harbor_k8s_proxy    = local.state.harbor_proxy.proxy_caches["k8s_io"].project_name

    # Asymmetric Routing Configuration
    kubeadm_static_routes = [
      for name, vip in local.state.network.infrastructure_vips : {
        to     = "${vip}/32"
        via    = local.p_net_config.lb_config.vip
        metric = 100
      }
      if contains([
        "vault-frontend",
        "harbor-bootstrapper-frontend", "harbor-frontend",
        "gitlab-postgres", "gitlab-redis", "gitlab-minio"
      ], name)
    ]

    # Compatibility Aliases (Optional)
    vip        = local.p_net_config.lb_config.vip
    pod_subnet = var.kubernetes_cluster_configuration.pod_subnet
  }

  ansible_extra_vars = {
    vault_ca_cert_b64       = local.sec_vault_agent_identity.ca_cert_b64
    vault_agent_role_id     = local.sec_vault_agent_identity.role_id
    vault_agent_secret_id   = local.sec_vault_agent_identity.secret_id
    vault_addr              = local.sys_vault_addr
    vault_role_name         = local.sec_vault_agent_identity.role_name
    vault_auth_path         = local.sec_vault_agent_identity.auth_path
    vault_agent_common_name = local.sec_vault_agent_identity.common_name
    vault_agent_cert_ttl    = local.state.vault_pki.pki_configuration.lease_durations.agent
    service_name            = local.primary_context.s_name
  }
}
