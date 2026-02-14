
output "hydrated_topology" {
  description = "Computed topology including calculated VIPs and Node IPs per segment"
  value       = local.hydrated_service_segments
}

output "infra_network" {
  description = "The calculated network configuration (Gateways, CIDRs) for NAT and HostOnly."
  value       = local.infra_network
}
