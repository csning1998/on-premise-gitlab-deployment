
output "network_slot_topology" {
  description = "Computed topology including calculated VIPs and Node IPs per segment."

  value = {
    for seg in local.net_service_segments : seg.name => seg.backend_servers
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
