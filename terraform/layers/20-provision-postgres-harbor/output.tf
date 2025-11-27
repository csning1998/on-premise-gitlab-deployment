
output "harbor_postgres_db_ip_list" {
  description = "List of Postgres node IPs for Harbor"
  value = [
    for node in var.postgres_cluster_config.nodes.postgres : node.ip
  ]
}

output "harbor_postgres_etcd_ip_list" {
  description = "List of Postgres etcd node IPs for Harbor"
  value = [
    for node in var.postgres_cluster_config.nodes.etcd : node.ip
  ]
}

output "harbor_postgres_haproxy_ip_list" {
  description = "List of Postgres HAProxy node IPs for Harbor"
  value = [
    for node in var.postgres_cluster_config.nodes.haproxy : node.ip
  ]
}

output "harbor_postgres_virtual_ip" {
  description = "Postgres virtual IP for Harbor"
  value       = var.postgres_cluster_config.ha_virtual_ip
}
