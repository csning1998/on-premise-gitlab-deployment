
output "service_vip" {
  description = "The virtual IP assigned to the Redis service from Central LB topology."
  value       = local.ansible_template_vars.redis_vip
}

output "credentials_system" {
  description = "System-level access credentials (SSH) for the cluster nodes."
  value       = local.sec_vm_creds
  sensitive   = true
}

output "credentials_redis" {
  description = "Redis access credentials and HA configuration."
  value       = local.sec_app_creds
  sensitive   = true
}

output "topology_cluster" {
  description = "The actual provisioned configuration for all Redis nodes."
  value       = module.infra_gitlab_redis.cluster_nodes
}

output "ansible_inventory" {
  description = "The generated Ansible inventory content and file path."
  value       = module.infra_gitlab_redis.ansible_inventory
}
