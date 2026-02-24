
output "service_vip" {
  description = "The virtual IP assigned to the Postgres service from Central LB topology."
  value       = local.net_service_vip
}



output "credentials_system" {
  description = "System-level access credentials (SSH) for the cluster nodes."
  value       = local.sec_system_creds
  sensitive   = true
}
output "credentials_postgres" {
  description = "Database-level credentials for Patroni and PostgreSQL replication."
  value       = local.sec_postgres_creds
  sensitive   = true
}

output "network_bindings" {
  description = "L2 network identity mapping for VM interface attachment (Verified from KVM)."
  value       = module.build_gitlab_postgres_cluster.network_bindings
}

output "network_parameters" {
  description = "L3 network configurations including gateways (Verified from KVM)."
  value       = module.build_gitlab_postgres_cluster.network_parameters
}

output "topology_cluster" {
  description = "The actual provisioned configuration for all Postgres and Etcd nodes."
  value       = module.build_gitlab_postgres_cluster.cluster_nodes
}
