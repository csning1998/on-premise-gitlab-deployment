

output "gitlab_redis_cluster_name" {
  description = "GitLab Redis cluster name."
  value       = local.cluster_name
}

output "gitlab_redis_ip_list" {
  description = "List of Redis node IPs for GitLab"
  value = [
    for node in var.gitlab_redis_compute.redis_config.nodes : node.ip
  ]
}

output "gitlab_redis_haproxy_ip_list" {
  description = "List of Redis HAProxy node IPs for GitLab"
  value = [
    for node in var.gitlab_redis_compute.haproxy_config.nodes : node.ip
  ]
}

output "gitlab_redis_virtual_ip" {
  description = "Redis virtual IP for GitLab"
  value       = var.gitlab_redis_compute.haproxy_config.virtual_ip
}

output "gitlab_redis_haproxy_stats_port" {
  description = "HAProxy stats port for GitLab Redis"
  value       = var.gitlab_redis_compute.haproxy_config.stats_port
}
