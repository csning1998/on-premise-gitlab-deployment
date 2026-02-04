
output "harbor_redis_ip_list" {
  description = "List of Redis node IPs for Harbor"
  value       = [for node in var.harbor_redis_compute.redis_config.nodes : node.ip]
}

output "harbor_redis_haproxy_ip_list" {
  description = "List of Redis HAProxy node IPs for Harbor"
  value       = [for node in var.harbor_redis_compute.haproxy_config.nodes : node.ip]
}

output "harbor_redis_virtual_ip" {
  description = "Redis virtual IP for Harbor"
  value       = var.harbor_redis_compute.haproxy_config.virtual_ip
}

output "harbor_redis_haproxy_stats_port" {
  description = "HAProxy stats port for Harbor Redis"
  value       = var.harbor_redis_compute.haproxy_config.stats_port
}
