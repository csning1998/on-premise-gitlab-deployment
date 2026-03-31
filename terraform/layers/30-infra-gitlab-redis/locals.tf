
# State Object
locals {
  state = {
    metadata  = data.terraform_remote_state.metadata.outputs
    volume    = data.terraform_remote_state.volume.outputs
    network   = data.terraform_remote_state.network.outputs # Handover through Layer 10
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

  # Resolve all targeted clusters into a components context map
  components_context = {
    for role, cluster_name in var.target_clusters : role => local.segments_map[cluster_name]
  }

  # Primary component definitions
  primary_role    = var.primary_role
  primary_context = local.components_context[local.primary_role]

  svc_identity = local.primary_context.identity
  svc_network  = local.primary_context.network

  # Fetch DNS from PKI metadata for the primary service entrypoint
  svc_pki_role = local.state.metadata.global_pki_map[local.primary_context.pki_key]
  svc_fqdn     = local.svc_pki_role.dns_san[0]
}

# 2. Network Context (Inherit from Load Balancer Handover)
locals {
  # Map physical networks for all components into an infrastructure map for middleware
  network_infrastructure_map = {
    for role, ctx in local.components_context : var.service_config[role].network_tier => local.state.network.infrastructure_map[ctx.identity.cluster_name]
  }

  # Helper for primary network configuration to reduce path redundancy
  p_net_config = local.network_infrastructure_map[var.service_config[local.primary_role].network_tier]
}

# 3. Security & Credentials Context (sec_ / pki_)
locals {
  sys_vault_addr = "https://${local.state.vault_sys.service_vip}:443"

  # System Level Credentials (OS/SSH)
  sec_vm_creds = {
    username             = data.vault_generic_secret.guest_vm.data["vm_username"]
    password             = data.vault_generic_secret.guest_vm.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.guest_vm.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.guest_vm.data["ssh_private_key_path"]
  }

  # Service Specific Credentials
  sec_app_creds = {
    masterauth  = data.vault_generic_secret.db_vars.data["redis_masterauth"]
    requirepass = data.vault_generic_secret.db_vars.data["redis_requirepass"]
    vrrp_secret = data.vault_generic_secret.db_vars.data["redis_vrrp_secret"]
  }

  # Component Specific Vault Identities
  sec_vault_role_key = local.svc_pki_role.key
  sec_vault_agent_identity = {
    vault_address = local.sys_vault_addr
    auth_path     = local.state.vault_pki.workload_identities_components[local.sec_vault_role_key].auth_path
    role_id       = local.state.vault_pki.workload_identities_components[local.sec_vault_role_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.component_roles[local.sec_vault_role_key].name
    secret_id     = vault_approle_auth_backend_role_secret_id.redis_agent.secret_id
    ca_cert_b64   = local.state.metadata.global_vault_pki.ca_cert
    common_name   = local.svc_fqdn
  }
}

# 4. Topology & Construction
locals {
  storage_pool_name = local.svc_identity.storage_pool_name

  topology_cluster = {
    components        = var.service_config
    storage_pool_name = local.storage_pool_name
  }

  # Map logical roles to their respective physical identities from SSoT
  node_identities = {
    for role, ctx in local.components_context : role => ctx.identity
  }
}

# 5. Ansible Configuration (Dynamic Inventory)
locals {
  ansible_template_vars = {
    access_scope         = local.p_net_config.network.hostonly.cidr
    redis_tls_port       = local.p_net_config.lb_config.ports["main"].frontend_port
    redis_vip            = local.p_net_config.lb_config.vip
    vault_vip            = local.state.vault_sys.service_vip
    redis_service_domain = local.sec_vault_agent_identity.common_name
  }

  ansible_extra_vars = {
    redis_masterauth        = local.sec_app_creds.masterauth
    redis_requirepass       = local.sec_app_creds.requirepass
    redis_vrrp_secret       = local.sec_app_creds.vrrp_secret
    vault_agent_common_name = local.sec_vault_agent_identity.common_name
  }
}
