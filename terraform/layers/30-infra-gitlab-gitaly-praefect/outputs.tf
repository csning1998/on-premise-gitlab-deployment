
output "service_vip" {
  description = "The virtual IP of the primary tier."
  value       = module.context.primary_net_config.lb_config.vip
}

output "service_vips" {
  description = "The virtual IPs assigned to each service tier."
  value = {
    gitaly           = module.context.network_infrastructure_map["gitaly"].lb_config.vip
    praefect         = module.context.network_infrastructure_map["praefect"].lb_config.vip
    praefect-patroni = module.context.network_infrastructure_map["praefect-patroni"].lb_config.vip
  }
}

output "topology_cluster" {
  description = "The actual provisioned configuration for all nodes."
  value       = module.infra_gitlab_gitaly_praefect.cluster_nodes
}

output "ansible_inventory" {
  description = "The generated Ansible inventory content and file path."
  value       = module.infra_gitlab_gitaly_praefect.ansible_inventory
}
