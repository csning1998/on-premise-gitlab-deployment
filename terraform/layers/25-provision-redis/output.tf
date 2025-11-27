
output "redis_ip_list" {
  description = "List of Redis node IPs"
  value = [
    for node in var.redis_cluster_config.nodes.redis : node.ip
  ]
}

output "redis_haproxy_ip_list" {
  description = "List of Redis HAProxy node IPs"
  value = [
    for node in var.redis_cluster_config.nodes.haproxy : node.ip
  ]
}

output "redis_virtual_ip" {
  description = "Redis virtual IP"
  value       = var.redis_cluster_config.ha_virtual_ip
}
