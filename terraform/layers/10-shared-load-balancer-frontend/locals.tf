
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_credentials = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base     = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_credentials.username
    password = local._gl_credentials.token
  }
}

# State Object
locals {
  state = {
    network  = data.terraform_remote_state.network.outputs
    metadata = data.terraform_remote_state.metadata.outputs
  }
  secrets = {
    credentials    = data.vault_kv_secret_v2.credentials.data # AppRole
    guest_vm       = data.vault_kv_secret_v2.guest_vm.data
    infrastructure = data.vault_kv_secret_v2.infrastructure.data
  }
}

# 1. Unified SSoT Alignment (Universal Segment Dictionary)
locals {
  # Zip Identity, Network, and VIP properties into a single O(1) lookup map.
  segments_map = merge([
    for s_name, components in local.state.network.global_topology_identity : {
      for c_name, identity in components : identity.cluster_name => {
        identity = identity
        network  = local.state.network.global_topology_network[s_name][c_name]
        vip      = lookup(local.state.network.infrastructure_map, identity.cluster_name, { lb_config = { vip = null } }).lb_config.vip
        s_name   = s_name
        c_name   = c_name
      }
    }
  ]...)

  # Global Asymmetric Routing Targets (Dynamic Discovery Projection)
  infrastructure_vips = {
    for k, v in local.segments_map : "${v.s_name}-${v.c_name}" => v.vip
    if v.vip != null
  }

  # Projection for module compatibility (SSoT Network Map)
  network_map = { for k, v in local.segments_map : k => v.network }

  # Target the Central LB using the unified SSoT key
  svc_cluster_name = var.target_cluster_name
  svc_context      = local.segments_map[local.svc_cluster_name]

  svc_identity    = local.svc_context.identity
  svc_network     = local.svc_context.network
  svc_fqdn        = local.state.network.global_domain_suffix
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
    for name, seg in local.state.network.service_segments : merge(seg, {
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
  pki_global_ca_b64 = local.state.network.global_vault_pki_b64

  # System Level Credentials (OS/SSH)
  sec_vm_credentials = {
    username             = local.secrets.guest_vm["vm_username"]
    password             = local.secrets.guest_vm["vm_password"]
    ssh_public_key_path  = local.secrets.guest_vm["ssh_public_key_path"]
    ssh_private_key_path = local.secrets.guest_vm["ssh_private_key_path"]
  }

  sec_haproxy_credentials = {
    haproxy_stats_pass   = local.secrets.infrastructure["haproxy_stats_pass"]
    keepalived_auth_pass = local.secrets.infrastructure["keepalived_auth_pass"]
  }

  ansible_template_config = {
    service_domain = local.svc_fqdn
    service_name   = local.svc_cluster_name
  }

  ansible_extra_config = {
    terraform_runner_subnet = local.net_lb_config.hostonly.cidr
    global_mss              = local.state.network.global_network_baseline.global_mss
    global_mtu              = local.state.network.global_network_baseline.global_mtu
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
