
output "service_vip" {
  description = "The virtual IP assigned to the Vault service from Central LB topology."
  value       = module.context.primary_net_config.lb_config.vip
}

output "ca_cert_path" {
  description = "The absolute path to the local Bootstrap CA certificate."
  value       = abspath(local_file.bootstrap_ca.filename)
}

output "vault_api_port" {
  description = "Vault API frontend port for L40 consumption."
  value       = module.context.primary_net_config.lb_config.ports["api"].frontend_port
}

output "node_exporter_targets" {
  description = "Node Exporter scrape targets (per-node IPs and port) for the Vault frontend VM fleet."
  value = {
    ips  = module.context.svc_network.node_ips
    port = module.context.node_exporter_port
  }
}
