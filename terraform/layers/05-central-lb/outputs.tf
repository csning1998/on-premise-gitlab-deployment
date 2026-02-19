
output "network_slot_topology" {
  description = "Computed topology including calculated VIPs and Node IPs per segment."

  value = {
    for seg in local.network_service_segments : seg.name => seg.backend_servers
  }
}


output "network_service_topology" {
  description = "All infrastructure and application details for each service."

  value = {
    for seg in local.network_service_segments : seg.name => {

      # 1. Network Infrastructure (L2 Bridge, L3 CIDR/Gateway)
      network = local.network_infrastructure[seg.name]

      # 2. Service Delivery (L3 VIP/VRID, L4 Ports)
      lb_config = {
        vip            = seg.vip
        vrid           = seg.vrid
        interface_name = seg.interface_name
        ports          = seg.ports
        tags           = seg.tags
      }
    }
  }
}

output "central_lb_info" {
  description = "Connection details for the Central LB itself."
  value       = local.network_infrastructure[var.service_catalog_name]
}
