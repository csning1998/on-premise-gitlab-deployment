
# State Object
locals {
  state = {
    topology = data.terraform_remote_state.topology.outputs
  }
}

# Network Map Reference
locals {
  svc_name        = var.service_catalog_name
  svc_network_map = local.state.topology.network_map
}

# Deterministic Bridge Naming (identical logic to 05-central-lb)
locals {
  net_bridge_naming = {
    for seg_key, seg_data in local.svc_network_map : seg_key => {
      host = "br-${substr(md5("${local.svc_name}-${seg_key}"), 0, 8)}"
      nat  = "br-${substr(md5("${local.svc_name}-${seg_key}"), 0, 8)}-nat"
    }
  }
}

# Full Infrastructure Map (All Segments: CLB own + all service segments)
locals {
  net_infrastructure = {
    for seg_key, seg_data in local.svc_network_map : seg_key => {
      hostonly = {
        name        = seg_key
        bridge_name = local.net_bridge_naming[seg_key].host
        gateway     = cidrhost(seg_data.cidr_block, 1)
        cidr        = seg_data.cidr_block
        prefix      = tonumber(split("/", seg_data.cidr_block)[1])
      }
      nat = {
        name        = "iac-${seg_key}-nat"
        bridge_name = local.net_bridge_naming[seg_key].nat
        gateway     = seg_data.nat_gateway
        cidr        = seg_data.nat_cidr_block
        prefix      = 24
        dhcp        = seg_data.nat_dhcp
      }
    }
  }
}

# Service Segments (non-CLB) — for outputs consumed by 05-central-lb
locals {
  net_sorted_segment_keys = sort([
    for k, v in local.svc_network_map : k
    if k != local.svc_name
  ])

  net_service_segments = [
    for seg_key in local.net_sorted_segment_keys : {
      name           = seg_key
      bridge_name    = local.net_bridge_naming[seg_key].host
      cidr           = local.svc_network_map[seg_key].cidr_block
      nat_cidr       = local.svc_network_map[seg_key].nat_cidr_block
      nat_gateway    = local.svc_network_map[seg_key].nat_gateway
      vrid           = local.svc_network_map[seg_key].vrid
      vip            = local.svc_network_map[seg_key].vip
      interface_name = local.svc_network_map[seg_key].interface_alias
      ports          = local.svc_network_map[seg_key].ports
      tags           = local.svc_network_map[seg_key].tags

      ip_range = local.svc_network_map[seg_key].ip_range

      backend_servers = [
        for i in range(
          local.svc_network_map[seg_key].ip_range.end_ip - local.svc_network_map[seg_key].ip_range.start_ip + 1
          ) : {
          name = "${seg_key}-slot-${local.svc_network_map[seg_key].ip_range.start_ip + i}"
          ip = cidrhost(
            local.svc_network_map[seg_key].cidr_block,
            local.svc_network_map[seg_key].ip_range.start_ip + i
          )
        }
      ]
    }
  ]
}
