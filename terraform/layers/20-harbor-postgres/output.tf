
output "harbor_postgres_db_ip_list" {
  description = "List of Postgres node IPs for Harbor"
  value       = [for node in var.harbor_postgres_compute.nodes : node.ip]
}

output "harbor_postgres_etcd_ip_list" {
  description = "List of Postgres etcd node IPs for Harbor"
  value       = [for node in var.harbor_postgres_compute.etcd_nodes : node.ip]
}

output "harbor_postgres_haproxy_ip_list" {
  description = "List of Postgres HAProxy node IPs for Harbor"
  value       = [for node in var.harbor_postgres_compute.ha_config.haproxy_nodes : node.ip]
}

output "harbor_postgres_virtual_ip" {
  description = "Postgres virtual IP for Harbor"
  value       = var.harbor_postgres_compute.ha_config.virtual_ip
}

output "harbor_postgres_haproxy_stats_port" {
  description = "Postgres HAProxy Stats Port for Harbor"
  value       = var.harbor_postgres_compute.ha_config.stats_port
}

output "harbor_postgres_haproxy_rw_port" {
  description = "Postgres HAProxy Read-Write Port for Harbor"
  value       = var.harbor_postgres_compute.ha_config.rw_proxy
}

output "harbor_postgres_haproxy_ro_port" {
  description = "Postgres HAProxy Read-Only Port for Harbor"
  value       = var.harbor_postgres_compute.ha_config.ro_proxy
}
