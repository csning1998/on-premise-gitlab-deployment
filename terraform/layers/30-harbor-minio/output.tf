
output "harbor_minio_cluster_name" {
  description = "Harbor MinIO cluster name."
  value       = local.cluster_name
}

output "harbor_minio_ip_list" {
  description = "List of MinIO node IPs for Harbor"
  value       = [for node in var.harbor_minio_compute.minio_config.nodes : node.ip]
}

output "harbor_minio_haproxy_ip_list" {
  description = "List of MinIO HAProxy node IPs for Harbor"
  value       = [for node in var.harbor_minio_compute.haproxy_config.nodes : node.ip]
}

output "harbor_minio_virtual_ip" {
  description = "MinIO virtual IP for Harbor"
  value       = var.harbor_minio_compute.haproxy_config.virtual_ip
}

output "harbor_minio_haproxy_ports" {
  description = "HAProxy ports for Harbor MinIO"
  value = {
    frontend_port_api     = var.harbor_minio_compute.haproxy_config.frontend_port_api
    frontend_port_console = var.harbor_minio_compute.haproxy_config.frontend_port_console
    backend_port_api      = var.harbor_minio_compute.haproxy_config.backend_port_api
    backend_port_console  = var.harbor_minio_compute.haproxy_config.backend_port_console
  }
}
