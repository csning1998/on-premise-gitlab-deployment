
output "postgres_ip_list" {
  description = "List of Postgres node IPs"
  value = [
    for node in var.postgres_cluster_config.nodes.postgres : node.ip
  ]
}

output "postgres_etcd_ip_list" {
  description = "List of Postgres etcd node IPs"
  value = [
    for node in var.postgres_cluster_config.nodes.etcd : node.ip
  ]
}

output "postgres_haproxy_ip_list" {
  description = "List of Postgres HAProxy node IPs"
  value = [
    for node in var.postgres_cluster_config.nodes.haproxy : node.ip
  ]
}

output "postgres_virtual_ip" {
  description = "Postgres virtual IP"
  value       = var.postgres_cluster_config.ha_virtual_ip
}
