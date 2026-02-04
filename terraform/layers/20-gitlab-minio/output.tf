
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

output "gitlab_minio_haproxy_ports" {
  description = "HAProxy ports for GitLab MinIO"
  value = {
    frontend_port_api     = var.gitlab_minio_compute.haproxy_config.frontend_port_api
    frontend_port_console = var.gitlab_minio_compute.haproxy_config.frontend_port_console
    backend_port_api      = var.gitlab_minio_compute.haproxy_config.backend_port_api
    backend_port_console  = var.gitlab_minio_compute.haproxy_config.backend_port_console
  }
}
