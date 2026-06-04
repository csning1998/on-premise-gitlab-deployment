
output "service_vip" {
  description = "The virtual IP assigned to the Postgres service from Central LB topology."
  value       = module.context.primary_net_config.lb_config.vip
}

output "credentials_system" {
  description = "System-level access credentials (SSH) for the cluster nodes."
  value       = module.context.sec_vm_creds
  sensitive   = true
}

output "credentials_postgres" {
  description = "Database-level credentials for Patroni and PostgreSQL replication."
  value       = local.sec_app_creds
  sensitive   = true
}

output "topology_cluster" {
  description = "The actual provisioned configuration for all Postgres and Etcd nodes."
  value       = module.infra_harbor_postgres.cluster_nodes
}

output "ansible_inventory" {
  description = "The generated Ansible inventory content and file path."
  value       = module.infra_harbor_postgres.ansible_inventory
}
