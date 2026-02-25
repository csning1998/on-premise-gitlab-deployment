
output "infrastructure_map" {
  description = "Physical realization bridging Layer 00 Math and HAProxy VIPs, mapped perfectly to O(1) SSoT Identity keys. Consumed by all 30-* and 40-* layers."

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
  value       = local.net_infrastructure[var.service_catalog_name]
}

output "service_segments" {
  description = "Ordered list of service segments — consumed by 05-central-lb for HAProxy and Keepalived config."
  value       = local.net_service_segments
}
