
output "network_slot_topology" {
  description = "Computed topology including calculated VIPs and Node IPs per segment."

  value = {
    for seg in local.net_service_segments : seg.name => seg.backend_servers
  }
}


output "infrastructure_map" {
  description = "Physical realization bridging Layer 00 Math and HAProxy VIPs, mapped perfectly to O(1) SSoT Identity keys"

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
  description = "Connection details for the Central LB itself."
  value       = local.net_infrastructure[var.service_catalog_name]
}
