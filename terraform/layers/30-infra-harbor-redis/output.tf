
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
  description = "Redis-level credentials for replication and access control."
  value       = local.sec_app_creds
  sensitive   = true
}

output "topology_cluster" {
  description = "The actual provisioned configuration for all Redis nodes."
  value       = module.redis_harbor.cluster_nodes
}
