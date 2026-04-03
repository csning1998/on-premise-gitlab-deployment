
# 1. State Hub (Cross-Layer SSoT)
locals {
  state = {
    metadata  = data.terraform_remote_state.metadata.outputs
    volume    = data.terraform_remote_state.volume.outputs
    network   = data.terraform_remote_state.network.outputs
    vault_sys = data.terraform_remote_state.vault_sys.outputs
    vault_pki = data.terraform_remote_state.vault_pki.outputs
    # Dependencies
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
    auth_path     = local.state.vault_pki.workload_identities_components[local.sec_vault_identity_key].auth_path
    role_id       = local.state.vault_pki.workload_identities_components[local.sec_vault_identity_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.component_roles[local.sec_vault_identity_key].name
    secret_id     = vault_approle_auth_backend_role_secret_id.kubeadm_agent.secret_id
    ca_cert_b64   = local.state.metadata.global_vault_pki.ca_cert
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

# 6. Ansible Infrastructure Template Variables
locals {
  # Dependency discovery: Use the physical SSoT key for the Harbor registry.
  registry_pki_key = local.state.harbor_registry.pki_key

  ansible_template_vars = {
    vip        = local.p_net_config.lb_config.vip
    pod_subnet = var.kubernetes_cluster_configuration.pod_subnet
    nat_prefix = join(".", slice(split(".", local.p_net_config.network.nat.gateway), 0, 3))

    registry_host = local.state.metadata.global_pki_map[local.registry_pki_key].dns_san[0]
    registry_vip  = local.state.harbor_registry.service_vip

    image_repository = "${local.state.harbor_registry.service_vip}/${local.state.harbor_proxy.proxy_caches["k8s_io"].project_name}"
    hostonly_gateway = local.p_net_config.network.hostonly.gateway

    # Port Mappings
    http_nodeport  = local.p_net_config.lb_config.ports["ingress-http"].backend_port
    https_nodeport = local.p_net_config.lb_config.ports["ingress-https"].backend_port
  }

  ansible_extra_vars = {
    vault_ca_cert_b64     = local.sec_vault_agent_identity.ca_cert_b64
    vault_agent_role_id   = local.sec_vault_agent_identity.role_id
    vault_agent_secret_id = vault_approle_auth_backend_role_secret_id.kubeadm_agent.secret_id
    vault_addr            = local.sys_vault_addr
    vault_role_name       = local.sec_vault_agent_identity.role_name
    service_name          = local.primary_context.s_name
  }
}
