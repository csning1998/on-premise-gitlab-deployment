
output "gitlab_minio_ip_list" {
  description = "List of MinIO node IPs for GitLab"
  value       = [for node in var.gitlab_minio_compute.nodes : node.ip]
}

output "gitlab_minio_haproxy_ip_list" {
  description = "List of MinIO HAProxy node IPs for GitLab"
  value       = [for node in var.gitlab_minio_compute.ha_config.haproxy_nodes : node.ip]
}

output "gitlab_minio_virtual_ip" {
  description = "MinIO virtual IP for GitLab"
  value       = var.gitlab_minio_compute.ha_config.virtual_ip
}
