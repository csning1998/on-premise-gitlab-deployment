
output "gitlab_postgres_db_ip_list" {
  description = "List of Postgres node IPs for GitLab"
  value = [
    for node in var.postgres_cluster_config.nodes.postgres : node.ip
  ]
}

output "gitlab_postgres_etcd_ip_list" {
  description = "List of Postgres etcd node IPs for GitLab"
  value = [
    for node in var.postgres_cluster_config.nodes.etcd : node.ip
  ]
}

output "gitlab_postgres_haproxy_ip_list" {
  description = "List of Postgres HAProxy node IPs for GitLab"
  value = [
    for node in var.postgres_cluster_config.nodes.haproxy : node.ip
  ]
}

output "gitlab_postgres_virtual_ip" {
  description = "Postgres virtual IP for GitLab"
  value       = var.postgres_cluster_config.ha_virtual_ip
}
