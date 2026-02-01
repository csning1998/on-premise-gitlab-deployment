
output "gitlab_minio_ip_list" {
  description = "List of MinIO node IPs for GitLab"
  value       = [for node in var.gitlab_minio_compute.minio_config.nodes : node.ip]
}

output "gitlab_minio_haproxy_ip_list" {
  description = "List of MinIO HAProxy node IPs for GitLab"
  value       = [for node in var.gitlab_minio_compute.haproxy_config.nodes : node.ip]
}

output "gitlab_minio_virtual_ip" {
  description = "MinIO virtual IP for GitLab"
  value       = var.gitlab_minio_compute.haproxy_config.virtual_ip
}
