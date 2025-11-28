
output "gitlab_postgres_db_ip_list" {
  description = "List of Postgres node IPs for GitLab"
  value       = [for node in var.gitlab_postgres_compute.nodes : node.ip]
}

output "gitlab_postgres_etcd_ip_list" {
  description = "List of Postgres etcd node IPs for GitLab"
  value       = [for node in var.gitlab_postgres_compute.etcd_nodes : node.ip]
}

output "gitlab_postgres_haproxy_ip_list" {
  description = "List of Postgres HAProxy node IPs for GitLab"
  value       = [for node in var.gitlab_postgres_compute.ha_config.haproxy_nodes : node.ip]
}

output "gitlab_postgres_virtual_ip" {
  description = "Postgres virtual IP for GitLab"
  value       = var.gitlab_postgres_compute.ha_config.virtual_ip
}
