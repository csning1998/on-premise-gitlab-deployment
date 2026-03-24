
# State Object
locals {
  state = {
    metadata  = data.terraform_remote_state.metadata.outputs # Source from `00-foundation-metadata`
    volume    = data.terraform_remote_state.volume.outputs   # Source from `05-foundation-volume`
    network   = data.terraform_remote_state.network.outputs  # Source from `10-shared-load-balancer`
    vault_sys = data.terraform_remote_state.vault_sys.outputs
    vault_pki = data.terraform_remote_state.vault_pki.outputs
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

# 3. Security & Credentials Context (sec_ / pki_ / sys_)
locals {
  sys_vault_addr = "https://${local.state.vault_sys.service_vip}:443"

  # System Level Credentials (OS/SSH)
  sec_vm_creds = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  # Service Specific Credentials (DB/PG)
  sec_app_creds = {
    replication_password = data.vault_generic_secret.db_vars.data["pg_replication_password"]
    superuser_password   = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
    vrrp_secret          = data.vault_generic_secret.db_vars.data["pg_vrrp_secret"]
  }

  # Component Specific Vault Identities
  sec_vault_role_key = local.svc_pki_role.key
  sec_vault_agent_identity = {
    ca_cert_b64   = local.state.vault_sys.security_pki_bundle.ca_cert
    common_name   = local.svc_fqdn
    role_id       = local.state.vault_pki.workload_identities_components[local.sec_vault_role_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.component_roles[local.sec_vault_role_key].name
    secret_id     = vault_approle_auth_backend_role_secret_id.postgres_agent.secret_id
    vault_address = local.sys_vault_addr
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
    access_scope = local.p_net_config.network.hostonly.cidr
    postgres_vip = local.p_net_config.lb_config.vip
    vault_vip    = local.state.vault_sys.service_vip
    nat_prefix   = join(".", slice(split(".", local.p_net_config.network.nat.gateway), 0, 3))
  }

  ansible_extra_vars = {
    pg_replication_password = local.sec_app_creds.replication_password
    pg_superuser_password   = local.sec_app_creds.superuser_password
    pg_vrrp_secret          = local.sec_app_creds.vrrp_secret
    vault_agent_common_name = local.sec_vault_agent_identity.common_name
  }
}
