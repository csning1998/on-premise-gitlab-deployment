
output "service_vip" {
  description = "The virtual IP assigned to the Postgres service from Central LB topology."
  value       = local.ansible_template_vars.postgres_vip
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
  description = "The actual provisioned configuration for all Postgres and Etcd nodes."
  value       = module.build_gitlab_postgres_cluster.cluster_nodes
}
