
output "service_vip" {
  description = "The virtual IP assigned to the Redis service from Central LB topology."
  value       = module.context.primary_net_config.lb_config.vip
}

output "topology_cluster" {
  description = "The actual provisioned configuration for all Redis nodes."
  value       = module.infra_gitlab_redis.cluster_nodes
}

output "ansible_inventory" {
  description = "The generated Ansible inventory content and file path."
  value       = module.infra_gitlab_redis.ansible_inventory
}
