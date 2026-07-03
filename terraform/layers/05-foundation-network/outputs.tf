
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
  value       = local.net_infrastructure[local.central_lb_key]
}

output "service_segments" {
  description = "Stable map of service segments — consumed by 05-central-lb for HAProxy and Keepalived config."
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
  description = "Pass-through of L00 topology identity map; consumed by L10 to build segments_map without reading L00 directly."
  value       = local.state.metadata.global_topology_identity
}

output "global_topology_network" {
  description = "Pass-through of L00 topology network map; consumed by L10 to build segments_map without reading L00 directly."
  value       = local.state.metadata.global_topology_network
}

output "global_network_baseline" {
  description = "Pass-through of L00 global network baseline (global_mtu, global_mss); consumed by L10 for Ansible extra vars."
  value       = local.state.metadata.global_network_baseline
}

output "global_domain_suffix" {
  description = "Pass-through of L00 root domain suffix; consumed by L10 for Ansible template service_domain."
  value       = local.state.metadata.global_domain_suffix
}

output "global_vault_pki_b64" {
  description = "Pass-through of L00 Bootstrap Vault TLS artifacts (CA cert, server cert/key, HAProxy bundle); consumed by L10 for PKI CA bundle."
  value       = local.state.metadata.global_vault_pki_b64
  sensitive   = true
}
