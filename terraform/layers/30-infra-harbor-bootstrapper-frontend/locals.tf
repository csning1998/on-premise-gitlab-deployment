
# State Object
locals {
  state = {
    metadata  = data.terraform_remote_state.metadata.outputs
    volume    = data.terraform_remote_state.volume.outputs
    network   = data.terraform_remote_state.load_balancer.outputs # Handover through Layer 10
    vault_pki = data.terraform_remote_state.vault_pki.outputs
    vault_sys = data.terraform_remote_state.vault_sys.outputs
  }
}

# 1. Unified SSoT Alignment
locals {
  # Zip Identity and Network properties into a single O(1) lookup map.
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

  # Target the cluster using the unified SSoT key passed via tfvars
  svc_cluster_name = var.target_cluster_name
  svc_context      = local.segments_map[local.svc_cluster_name]

  svc_identity = local.svc_context.identity
  svc_network  = local.svc_context.network
  svc_name     = local.svc_context.s_name

  # Fetch DNS from PKI metadata (mapped by s_name-c_name)
  svc_pki_role = local.state.metadata.global_pki_map[local.svc_context.pki_key]
  svc_fqdn     = local.svc_pki_role.dns_san[0]
}

# 2. Network Context (Inherit from Load Balancer Handover)
locals {
  # Layer 10 (network state) provides infrastructure_map keyed by cluster_name
  net_physical_infra = local.state.network.infrastructure_map[local.svc_cluster_name]

  # Single map of raw infrastructures for HA middleware consumption
  # Act as an adapter, mapping the true physical network to the generic "default" tier.
  network_infrastructure_map = {
    "default" = local.net_physical_infra
  }
}

# 3. Security & Credentials Context (sec_ / pki_)
locals {
  sys_vault_addr = "https://${local.state.vault_sys.service_vip}:443"

  # System Level Credentials (OS/SSH)
  sec_vm_creds = {
    username             = data.vault_kv_secret_v2.guest_vm.data["vm_username"]
    password             = data.vault_kv_secret_v2.guest_vm.data["vm_password"]
    ssh_public_key_path  = data.vault_kv_secret_v2.guest_vm.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_kv_secret_v2.guest_vm.data["ssh_private_key_path"]
  }

  # Service Specific Credentials
  sec_app_creds = {
    harbor_admin_password = data.vault_kv_secret_v2.db_vars.data["harbor_bootstrapper_admin_password"]
    harbor_pg_db_password = data.vault_kv_secret_v2.db_vars.data["harbor_bootstrapper_pg_db_password"]
  }

  # Component Specific Vault Identities
  sec_vault_role_key = local.svc_pki_role.key
  sec_vault_agent_identity = {
    common_name   = local.svc_fqdn
    ca_cert_b64   = local.state.vault_pki.bootstrap_ca_b64.content_b64
    auth_path     = local.state.vault_pki.workload_identities_approle[local.sec_vault_role_key].auth_path
    role_id       = local.state.vault_pki.workload_identities_approle[local.sec_vault_role_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.pki_roles[local.sec_vault_role_key].name
    secret_id     = vault_approle_auth_backend_role_secret_id.bootstrap_harbor_agent.secret_id
    vault_address = local.sys_vault_addr
  }
}

# 4. Topology & Construction
locals {
  storage_pool_name = local.svc_identity.storage_pool_name

  topology_cluster = {
    components        = var.harbor_bootstrapper_config
    storage_pool_name = local.storage_pool_name
  }

  # Map dynamic component names back to their single physical identity
  node_identities = {
    for comp_name, comp_config in var.harbor_bootstrapper_config : comp_name => local.svc_identity
  }
}

# 5. Ansible Configuration (Dynamic Inventory)
locals {
  ansible_template_vars = {
    # Service Identifiers
    service_identifier           = local.svc_name
    bstrap_harbor_fqdn           = local.svc_fqdn
    bstrap_harbor_service_domain = local.svc_identity.cluster_name

    # Networking & HA
    bstrap_harbor_vip              = local.net_physical_infra.lb_config.vip
    bstrap_harbor_tls_port         = local.net_physical_infra.lb_config.ports["https"].frontend_port
    bstrap_harbor_mtls_node_subnet = local.net_physical_infra.network.hostonly.cidr
    vault_vip                      = local.state.vault_sys.service_vip
    global_mss                     = local.state.metadata.global_network_baseline.global_mss

    # Cluster Topology
    bstrap_harbor_cluster_ips = [
      for comp_name, comp_config in var.harbor_bootstrapper_config : [
        for node_suffix, node_data in comp_config.nodes :
        cidrhost(local.net_physical_infra.network.hostonly.cidr, node_data.ip_suffix)
      ]
    ][0] # Harbor Bootstrapper is a single component

    # Asymmetric Routing (Flattened)
    bstrap_harbor_static_route_to     = "${local.state.vault_sys.service_vip}/32"
    bstrap_harbor_static_route_via    = local.net_physical_infra.lb_config.vip
    bstrap_harbor_static_route_metric = 100

    # Compatibility Aliases
    access_scope = local.net_physical_infra.network.hostonly.cidr
    service_name = local.svc_name
  }

  ansible_extra_vars = {
    harbor_bootstrapper_admin_password = local.sec_app_creds.harbor_admin_password
    harbor_bootstrapper_pg_db_password = local.sec_app_creds.harbor_pg_db_password
    vault_agent_common_name            = local.sec_vault_agent_identity.common_name
    vault_agent_cert_ttl               = local.state.vault_pki.pki_configuration.lease_durations.agent
  }
}
