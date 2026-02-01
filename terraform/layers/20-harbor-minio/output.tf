
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
