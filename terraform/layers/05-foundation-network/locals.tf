
# State Object
locals {
  state = {
    metadata = data.terraform_remote_state.metadata.outputs
  }
}

# Network Map Reference: Zip Network Attributes with Identity Naming SSoT
locals {
  # 1. Zip the topological maps into a single manageable structure
  # Identity Map provides naming (Bridge, Pool, etc.), Network Map provides IPv4 attributes.
  # Use identity.cluster_name as the primary O(1) key for downstream realization.
  segments = merge([
    for s_name, components in local.state.metadata.global_topology_identity : {
      for c_name, identity in components : identity.cluster_name => {
        identity = identity
        network  = local.state.metadata.global_topology_network[s_name][c_name]
      }
    }
  ]...)

  # SSoT Naming: Directly use the cluster_name of the Central Load Balancer frontend.
  central_lb_key = "core-central-lb-frontend"
}

# Full Infrastructure Map (All Segments: Consumed by libvirt_network resources)
locals {
  net_infrastructure = {
    for key, data in local.segments : key => {
      hostonly = {
        name        = data.identity.cluster_name
        bridge_name = data.identity.bridge_name_host
        gateway     = cidrhost(data.network.cidr_block, 1)
        cidr        = data.network.cidr_block
        prefix      = 24
      }
      nat = {
        name        = "${data.identity.cluster_name}-nat"
        bridge_name = data.identity.bridge_name_nat
        gateway     = data.network.nat_gateway
        cidr        = data.network.nat_cidr_block
        prefix      = 24
        dhcp        = data.network.nat_dhcp
      }
    }
  }
}

# Service Segments (non-CLB) — for HAProxy/Keepalived/Identity outputs
locals {
  net_sorted_segment_keys = sort([
    for k, v in local.segments : k
    if k != local.central_lb_key && length(v.network.ports) > 0
  ])

  net_service_segments = [
    for key in local.net_sorted_segment_keys : {
      name           = key
      bridge_name    = local.segments[key].identity.bridge_name_host
      cidr           = local.segments[key].network.cidr_block
      nat_cidr       = local.segments[key].network.nat_cidr_block
      nat_gateway    = local.segments[key].network.nat_gateway
      vrid           = local.segments[key].network.vrid
      vip            = local.segments[key].network.vip
      interface_name = local.segments[key].network.interface_alias
      ports          = local.segments[key].network.ports
      tags           = local.segments[key].network.tags

      ip_range = local.segments[key].network.ip_range

      # Use node_ips derived from Layer 00 directly to avoid re-calculation
      backend_servers = [
        for idx, ip in local.segments[key].network.node_ips : {
          name = "${local.segments[key].identity.node_name_prefix}-${local.segments[key].network.ip_range.start_ip + idx}"
          ip   = ip
        }
      ]
    }
  ]
}
