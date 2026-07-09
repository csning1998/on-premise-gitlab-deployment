
output "harbor_bootstrapper_fqdn" {
  description = "The FQDN of the Bootstrap Harbor service."
  value       = module.context.svc_fqdn
}

output "service_vip" {
  description = "The virtual IP assigned to the Bootstrap Harbor service from Central LB topology."
  value       = module.context.primary_net_config.lb_config.vip
}

output "topology_node" {
  description = "The actual provisioned configuration for Bootstrap Harbor node."
  value       = module.infra_harbor_bootstrapper.cluster_nodes
}

output "pki_key" {
  description = "The physical SSoT PKI key associated with the Harbor Bootstrapper service."
  value       = module.context.primary_context.pki_key
}

output "ansible_inventory" {
  description = "The generated Ansible inventory content and file path."
  value       = module.infra_harbor_bootstrapper.ansible_inventory
}

output "ssh_config_file_path" {
  description = "The path to the generated SSH configuration file."
  value       = module.infra_harbor_bootstrapper.ssh_config_file_path
}

output "node_exporter_targets" {
  description = "Node Exporter scrape target for the Harbor Bootstrapper node."
  value = {
    ips  = module.context.svc_network.node_ips
    port = module.context.node_exporter_port
  }
}
