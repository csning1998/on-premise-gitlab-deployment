
# State Object
locals {
  state = {
    metadata  = data.terraform_remote_state.metadata.outputs
    volume    = data.terraform_remote_state.volume.outputs
    network   = data.terraform_remote_state.network.outputs # Handover through Layer 10
    vault_sys = data.terraform_remote_state.vault_sys.outputs
    vault_pki = data.terraform_remote_state.vault_pki.outputs
  }
}

# Service Context
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

  # Align with Postgres/Redis: Dynamic identity map for module input
  node_identities = {
    for role, cluster_name in var.target_clusters : role => local.segments_map[cluster_name].identity
  }
}

# Network Context
locals {
  # Map physical networks for all components into an infrastructure map for middleware
  network_infrastructure_map = {
    for role, ctx in local.components_context : var.service_config[role].network_tier => local.state.network.infrastructure_map[ctx.identity.cluster_name]
  }

  # Helper for primary network configuration to reduce path redundancy
  p_net_config = local.network_infrastructure_map[var.service_config[local.primary_role].network_tier]
}

# Security & App Context
locals {
  sys_vault_addr = "https://${local.state.vault_sys.service_vip}:443"

  # System Credentials (OS/SSH)
  sec_system_creds = {
    username             = data.vault_generic_secret.guest_vm.data["vm_username"]
    password             = data.vault_generic_secret.guest_vm.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.guest_vm.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.guest_vm.data["ssh_private_key_path"]
  }

  # Database Credentials (MinIO)
  sec_db_creds = {
    minio_root_user     = data.vault_generic_secret.db_vars.data["minio_root_user"]
    minio_root_password = data.vault_generic_secret.db_vars.data["minio_root_password"]
    minio_vrrp_secret   = data.vault_generic_secret.db_vars.data["minio_vrrp_secret"]
  }

  # Vault Agent Identity Prep
  sec_vault_identity_key = local.primary_context.pki_key

  sec_vault_agent_identity = {
    vault_address = local.sys_vault_addr
    auth_path     = local.state.vault_pki.workload_identities_approle[local.sec_vault_identity_key].auth_path
    role_id       = local.state.vault_pki.workload_identities_approle[local.sec_vault_identity_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.pki_roles[local.sec_vault_identity_key].name
    secret_id     = vault_approle_auth_backend_role_secret_id.minio_agent.secret_id
    ca_cert_b64   = local.state.vault_pki.bootstrap_ca_b64.content_b64
    common_name   = local.svc_fqdn
  }
}

# Topology Component Construction
locals {
  storage_pool_name = local.svc_identity.storage_pool_name

  topology_cluster = {
    storage_pool_name = local.storage_pool_name
    components        = var.service_config
  }
}

# 5. Ansible Configuration (Dynamic Inventory)
locals {
  ansible_template_vars = {
    # Service Identifiers
    service_identifier   = local.svc_identity.cluster_name
    minio_cluster_name   = "${local.svc_identity.cluster_name}-minio-cluster"
    minio_service_domain = local.sec_vault_agent_identity.common_name

    # Networking & HA
    minio_ha_virtual_ip         = local.p_net_config.lb_config.vip
    minio_tls_node_subnet       = local.p_net_config.network.hostonly.cidr
    minio_nat_subnet_prefix     = join(".", slice(split(".", local.p_net_config.network.nat.gateway), 0, 3))
    minio_frontend_port_api     = local.p_net_config.lb_config.ports["api"].frontend_port
    minio_frontend_port_console = local.p_net_config.lb_config.ports["console"].frontend_port
    vault_vip                   = local.state.vault_sys.service_vip
    global_mss                  = local.state.metadata.global_network_baseline.global_mss

    # Cluster Topology
    minio_cluster_ips = [
      for node_suffix, node_data in var.service_config["minio"].nodes :
      cidrhost(local.p_net_config.network.hostonly.cidr, node_data.ip_suffix)
    ]

    # Asymmetric Routing (Flattened)
    minio_static_route_to     = "${local.state.vault_sys.service_vip}/32"
    minio_static_route_via    = local.p_net_config.lb_config.vip
    minio_static_route_metric = 100

    # Compatibility Aliases (Optional)
    access_scope = local.p_net_config.network.hostonly.cidr
    minio_vip    = local.p_net_config.lb_config.vip
  }

  ansible_extra_vars = {
    minio_root_user         = local.sec_db_creds.minio_root_user
    minio_root_password     = local.sec_db_creds.minio_root_password
    minio_vrrp_secret       = local.sec_db_creds.minio_vrrp_secret
    vault_agent_common_name = local.sec_vault_agent_identity.common_name
    vault_agent_cert_ttl    = local.state.vault_pki.pki_configuration.lease_durations.agent
  }
}
