
output "service_vip" {
  description = "The virtual IP of the primary tier."
  value       = local.p_net_config.lb_config.vip
}

output "service_vips" {
  description = "The virtual IPs assigned to each service tier."
  value = {
    gitaly           = lookup(local.network_infrastructure_map, "gitaly", null) != null ? local.network_infrastructure_map["gitaly"].lb_config.vip : ""
    praefect         = lookup(local.network_infrastructure_map, "praefect", null) != null ? local.network_infrastructure_map["praefect"].lb_config.vip : ""
    praefect-patroni = lookup(local.network_infrastructure_map, "praefect-patroni", null) != null ? local.network_infrastructure_map["praefect-patroni"].lb_config.vip : ""
  }
}

output "credentials_system" {
  description = "System-level access credentials (SSH) for the cluster nodes."
  value       = local.sec_vm_creds
  sensitive   = true
}

output "credentials_postgres" {
  description = "Database-level credentials for Patroni and PostgreSQL replication."
  value       = local.sec_app_creds
  sensitive   = true
}

output "topology_cluster" {
  description = "The actual provisioned configuration for all nodes."
  value       = module.infra_gitlab_gitaly_praefect.cluster_nodes
}

output "ansible_inventory" {
  description = "The generated Ansible inventory content and file path."
  value       = module.infra_gitlab_gitaly_praefect.ansible_inventory
}
