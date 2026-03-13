
output "service_vip" {
  description = "The virtual IP assigned to the Vault service from Central LB topology."
  value       = local.net_service_vip
}

output "credentials_system" {
  description = "System-level access credentials for the cluster nodes."
  value       = local.sec_system_creds
  sensitive   = true
}

output "credentials_redis" {
  description = "Database-level credentials for Patroni and PostgreSQL replication."
  value       = local.sec_redis_creds
  sensitive   = true
}

output "topology_cluster" {
  description = "The actual provisioned configuration for Vault nodes."
  value       = module.redis_gitlab.cluster_nodes
}
