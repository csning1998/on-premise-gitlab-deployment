
output "harbor_redis_ip_list" {
  description = "List of Redis node IPs for Harbor"
  value = [
    for node in var.redis_cluster_config.nodes.redis : node.ip
  ]
}

output "harbor_redis_haproxy_ip_list" {
  description = "List of Redis HAProxy node IPs for Harbor"
  value = [
    for node in var.redis_cluster_config.nodes.haproxy : node.ip
  ]
}

output "harbor_redis_virtual_ip" {
  description = "Redis virtual IP for Harbor"
  value       = var.redis_cluster_config.ha_virtual_ip
}
