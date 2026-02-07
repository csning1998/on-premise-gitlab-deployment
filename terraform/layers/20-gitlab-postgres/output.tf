
output "gitlab_postgres_cluster_name" {
  description = "GitLab Postgres cluster name."
  value       = local.cluster_name
}

output "gitlab_postgres_db_ip_list" {
  description = "List of Postgres node IPs for GitLab"
  value       = [for node in var.gitlab_postgres_compute.postgres_config.nodes : node.ip]
}

output "gitlab_postgres_etcd_ip_list" {
  description = "List of Postgres etcd node IPs for GitLab"
  value       = [for node in var.gitlab_postgres_compute.etcd_config.nodes : node.ip]
}

output "gitlab_postgres_haproxy_ip_list" {
  description = "List of Postgres HAProxy node IPs for GitLab"
  value       = [for node in var.gitlab_postgres_compute.haproxy_config.nodes : node.ip]
}

output "gitlab_postgres_virtual_ip" {
  description = "Postgres virtual IP for GitLab"
  value       = var.gitlab_postgres_compute.haproxy_config.virtual_ip
}

output "gitlab_postgres_haproxy_stats_port" {
  description = "Postgres HAProxy Stats Port for GitLab"
  value       = var.gitlab_postgres_compute.haproxy_config.stats_port
}

output "gitlab_postgres_haproxy_rw_port" {
  description = "Postgres HAProxy Read-Write Port for GitLab"
  value       = var.gitlab_postgres_compute.haproxy_config.rw_proxy
}

output "gitlab_postgres_haproxy_ro_port" {
  description = "Postgres HAProxy Read-Only Port for GitLab"
  value       = var.gitlab_postgres_compute.haproxy_config.ro_proxy
}
