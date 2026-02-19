
output "service_vip" {
  description = "The virtual IP assigned to the Postgres service from Central LB topology."
  value       = local.service_vip
}

output "security_pki_bundle" {
  description = "PKI artifacts (Root CA) used for trust establishment."
  value       = local.security_pki_bundle
  sensitive   = true
}

output "credentials_system" {
  description = "System-level access credentials (SSH) for the cluster nodes."
  value       = local.credentials_system
  sensitive   = true
}
output "credentials_postgres" {
  description = "Database-level credentials for Patroni and PostgreSQL replication."
  value       = local.credentials_postgres
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
