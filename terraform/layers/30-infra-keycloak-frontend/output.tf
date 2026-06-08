
output "keycloak_fqdn" {
  description = "The FQDN of the Keycloak service."
  value       = module.context.svc_fqdn
}

output "service_vip" {
  description = "The virtual IP assigned to the Keycloak service from Central LB topology."
  value       = module.context.primary_net_config.lb_config.vip
}

output "topology_node" {
  description = "The actual provisioned configuration for Keycloak node."
  value       = module.keycloak_cluster.cluster_nodes
}

output "pki_key" {
  description = "The physical SSoT PKI key associated with the Keycloak service."
  value       = module.context.primary_context.pki_key
}

output "ansible_inventory" {
  description = "The generated Ansible inventory content and file path."
  value       = module.keycloak_cluster.ansible_inventory
}

output "ssh_config_file_path" {
  description = "The path to the generated SSH configuration file."
  value       = module.keycloak_cluster.ssh_config_file_path
}
