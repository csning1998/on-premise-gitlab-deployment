
output "bstrap_harbor_fqdn" {
  description = "The FQDN of the Bootstrap Harbor service."
  value       = local.svc_fqdn
}

output "service_vip" {
  description = "The virtual IP assigned to the Bootstrap Harbor service from Central LB topology."
  value       = local.net_physical_infra.lb_config.vip
}

output "credentials_system" {
  description = "System-level access credentials for the cluster nodes."
  value       = local.sec_vm_creds
  sensitive   = true
}

output "credentials_app" {
  description = "Application-level credentials for Harbor."
  value       = local.sec_app_creds
  sensitive   = true
}

output "topology_node" {
  description = "The actual provisioned configuration for Bootstrap Harbor node."
  value       = module.bootstrap_harbor.cluster_nodes
}

output "pki_key" {
  description = "The physical SSoT PKI key associated with the Harbor Bootstrapper service."
  value       = local.svc_context.pki_key
}

output "ansible_inventory" {
  description = "The generated Ansible inventory content and file path."
  value       = module.bootstrap_harbor.ansible_inventory
}

output "ssh_config_file_path" {
  description = "The path to the generated SSH configuration file."
  value       = module.bootstrap_harbor.ssh_config_file_path
}
