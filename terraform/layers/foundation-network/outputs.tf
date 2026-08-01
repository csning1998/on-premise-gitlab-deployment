
output "infrastructure_map" {
  description = "Physical realization bridging foundation-metadata Math and HAProxy VIPs, mapped perfectly to O(1) SSoT Identity keys. Consumed by all infra-* and provision-* layers."

  value = {
    for seg in local.net_service_segments : seg.name => {
      # 1. Physical Infrastructure (Libvirt bridges, IPs)
      network = local.net_infrastructure[seg.name]

      # 2. HAProxy / Keepalived Details
      lb_config = {
        vip            = seg.vip
        vrid           = seg.vrid
        interface_name = seg.interface_name
        ports          = seg.ports
        tags           = seg.tags
      }

      # 3. Available Node IP slots for downstream consumption
      backend_servers = seg.backend_servers
    }
  }
}

output "central_lb_info" {
  description = "Physical network configuration for the Central LB's own segment."
  value       = local.net_infrastructure[local.central_lb_key]
}

output "service_segments" {
  description = "Stable map of service segments, consumed by 05-central-lb for HAProxy and Keepalived configuration."
  value       = local.net_service_segments
}

output "dns_mapping" {
  description = "SSoT DNS mapping for verification of Grouping and Sorting logic."
  value = [
    for ip in sort(distinct([for r in local.state.metadata.global_dns_records : r.ip])) : {
      ip        = ip
      hostnames = sort(distinct([for r in local.state.metadata.global_dns_records : r.hostname if r.ip == ip]))
    }
  ]
}

output "global_topology_identity" {
  description = "Pass-through of foundation-metadata topology identity map; consumed by shared-load-balancer-frontend to build segments_map without reading foundation-metadata directly."
  value       = local.state.metadata.global_topology_identity
}

output "global_topology_network" {
  description = "Pass-through of foundation-metadata topology network map; consumed by shared-load-balancer-frontend to build segments_map without reading foundation-metadata directly."
  value       = local.state.metadata.global_topology_network
}

output "global_network_baseline" {
  description = "Pass-through of foundation-metadata global network baseline (global_mtu, global_mss); consumed by shared-load-balancer-frontend for Ansible extra vars."
  value       = local.state.metadata.global_network_baseline
}

output "global_domain_suffix" {
  description = "Pass-through of foundation-metadata root domain suffix; consumed by shared-load-balancer-frontend for Ansible template service_domain."
  value       = local.state.metadata.global_domain_suffix
}
