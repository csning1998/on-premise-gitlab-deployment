
output "gitlab_redis_ip_list" {
  description = "List of Redis node IPs for GitLab"
  value = [
    for node in var.redis_cluster_config.nodes.redis : node.ip
  ]
}

output "gitlab_redis_haproxy_ip_list" {
  description = "List of Redis HAProxy node IPs for GitLab"
  value = [
    for node in var.redis_cluster_config.nodes.haproxy : node.ip
  ]
}

output "gitlab_redis_virtual_ip" {
  description = "Redis virtual IP for GitLab"
  value       = var.redis_cluster_config.ha_virtual_ip
}
