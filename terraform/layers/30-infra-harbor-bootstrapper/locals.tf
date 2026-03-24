
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
  pki_global_ca  = local.state.metadata.global_vault_pki # PKI Artifacts
  sys_vault_addr = "https://${local.state.vault_sys.service_vip}:443"

  # System Level Credentials (OS/SSH)
  sec_vm_creds = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  # Service Specific Credentials
  sec_app_creds = {
    harbor_admin_password = data.vault_generic_secret.db_vars.data["harbor_bootstrapper_admin_password"]
    harbor_pg_db_password = data.vault_generic_secret.db_vars.data["harbor_bootstrapper_pg_db_password"]
  }

  # Component Specific Vault Identities
  sec_vault_role_key = local.svc_pki_role.key
  sec_vault_agent_identity = {
    ca_cert_b64   = local.pki_global_ca.ca_cert
    common_name   = local.svc_fqdn
    role_id       = local.state.vault_pki.workload_identities_components[local.sec_vault_role_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.component_roles[local.sec_vault_role_key].name
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
    access_scope        = local.network_infrastructure_map["default"].network.hostonly.cidr
    dev_harbor_tls_port = local.network_infrastructure_map["default"].lb_config.ports["https"].frontend_port
    dev_harbor_vip      = local.net_physical_infra.lb_config.vip
    nat_gateway         = local.network_infrastructure_map["default"].network.nat.gateway
    service_name        = local.svc_name
    vault_vip           = local.state.vault_sys.service_vip
  }

  ansible_extra_vars = merge(
    {
      ansible_user                       = local.sec_vm_creds.username
      harbor_bootstrapper_admin_password = local.sec_app_creds.harbor_admin_password
      harbor_bootstrapper_pg_db_password = local.sec_app_creds.harbor_pg_db_password
      terraform_runner_subnet            = local.network_infrastructure_map["default"].network.hostonly.cidr
    },
    local.pki_global_ca != null && length(keys(local.pki_global_ca)) > 0 ? {
      vault_server_cert = local.pki_global_ca.server_cert
      vault_server_key  = local.pki_global_ca.server_key
      vault_ca_cert     = local.pki_global_ca.ca_cert
    } : {}
  )
}
