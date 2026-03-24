
# State Object
locals {
  state = {
    metadata = data.terraform_remote_state.metadata.outputs
    network  = data.terraform_remote_state.network.outputs
  }
}

# 1. Unified SSoT Alignment (Flatten nested Layer 00 outputs into a single map)
locals {
  # Zip Identity and Network properties into a single O(1) lookup map.
  # This serves as the "Universal Segment Dictionary" for this layer.
  segments_map = merge([
    for s_name, components in local.state.metadata.global_topology_identity : {
      for c_name, identity in components : identity.cluster_name => {
        identity = identity
        network  = local.state.metadata.global_topology_network[s_name][c_name]
      }
    }
  ]...)

  # Projection for module compatibility (SSoT Network Map)
  network_map = { for k, v in local.segments_map : k => v.network }

  # Target the Central LB using the unified SSoT key
  svc_cluster_name = var.target_cluster_name
  svc_context      = local.segments_map[local.svc_cluster_name]

  svc_identity    = local.svc_context.identity
  svc_network     = local.svc_context.network
  svc_fqdn        = local.state.metadata.global_domain_suffix
  svc_node_prefix = local.svc_identity.node_name_prefix
}

# 2. Network Context (delegated to `05-foundation-network`)
locals {
  # Deterministic Ordering for node naming
  net_sorted_node_keys = sort(keys(var.node_config))

  net_node_naming_map = {
    for idx, key in local.net_sorted_node_keys :
    key => "${local.svc_node_prefix}-${format("%02d", idx)}"
  }

  # Handover from `05-foundation-network`
  net_infrastructure = local.state.network.infrastructure_map
  net_lb_config      = local.state.network.central_lb_info

  # CIDR scopes and specific segment data
  net_access_scope = local.net_lb_config.hostonly.cidr
}

locals {
  # Service Segments: augment from Layer 05 with local node_ips (depends on `var.node_config`)
  net_service_segments = [
    for seg in local.state.network.service_segments : merge(seg, {
      node_ips = {
        for node_name, node_spec in var.node_config : local.net_node_naming_map[node_name] =>
        cidrhost(seg.cidr, node_spec.ip_suffix)
      }
    })
    # Filter: Skip the CLB itself and services with self-managed load balancing (e.g. Kubeadm VIPs)
    if seg.name != local.svc_cluster_name && !contains(seg.tags, "self-managed-lb")
  ]
}

# 3. Security & Credentials Context (sec_ / pki_)
locals {
  pki_global_ca = local.state.metadata.global_vault_pki

  # System Level Credentials (OS/SSH)
  sec_vm_creds = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  sec_haproxy_creds = {
    haproxy_stats_pass   = data.vault_generic_secret.infra_vars.data["haproxy_stats_pass"]
    keepalived_auth_pass = data.vault_generic_secret.infra_vars.data["keepalived_auth_pass"]
  }

  ansible_template_vars = {
    ansible_ssh_user = local.sec_vm_creds.username
    service_domain   = local.svc_fqdn
    service_name     = local.svc_cluster_name
  }

  ansible_extra_vars = {
    terraform_runner_subnet = local.net_lb_config.hostonly.cidr
  }
}

# 4. Topology Construction
locals {
  storage_pool_name = local.svc_identity.storage_pool_name

  topology_nodes = {
    for node_name, node_spec in var.node_config : local.net_node_naming_map[node_name] => merge(node_spec, {
      base_image_path = var.base_image_path
    })
  }
}
