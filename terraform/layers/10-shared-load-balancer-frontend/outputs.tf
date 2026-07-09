
output "network_slot_topology" {
  description = "Computed topology including calculated VIPs and Node IPs per segment."

  value = {
    for seg in local.net_service_segments : seg.name => seg.backend_servers
  }
}

output "node_exporter_targets" {
  description = "Node Exporter scrape targets for the Central LB VM fleet itself (excluded from net_service_segments)."
  value = {
    ips  = local.state.network.global_topology_network["central-lb"]["frontend"].node_ips
    port = local.state.network.global_network_baseline.node_exporter_port
  }
}

output "infrastructure_map" {
  description = "Physical realization bridging Layer 00 Math and HAProxy VIPs, mapped perfectly to O(1) SSoT Identity keys"
  value       = data.terraform_remote_state.network.outputs.infrastructure_map
}

output "central_lb_info" {
  description = "Connection details for the Central LB itself."
  value       = data.terraform_remote_state.network.outputs.central_lb_info
}


output "infrastructure_vips" {
  description = "Aggregated list of all internal service VIPs requiring static route overrides."
  value       = local.infrastructure_vips
}

output "global_topology_identity" {
  description = "Pass-through of L00 topology identity map; consumed by L30+ context module for VM naming and storage pool resolution."
  value       = local.state.network.global_topology_identity
}

output "global_topology_network" {
  description = "Pass-through of L00 topology network map; consumed by L30+ context module for IP, port, and CIDR resolution."
  value       = local.state.network.global_topology_network
}

output "global_network_baseline" {
  description = "Pass-through of L00 global network baseline (global_mtu, global_mss); consumed by L30+ context module."
  value       = local.state.network.global_network_baseline
}

output "global_domain_suffix" {
  description = "Pass-through of L00 root domain suffix; consumed by L30+ for service FQDN construction."
  value       = local.state.network.global_domain_suffix
}
