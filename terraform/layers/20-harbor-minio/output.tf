
output "harbor_minio_ip_list" {
  description = "List of MinIO node IPs for Harbor"
  value = [
    for node in var.minio_cluster_config.nodes.minio : node.ip
  ]
}

output "harbor_minio_haproxy_ip_list" {
  description = "List of MinIO HAProxy node IPs for Harbor"
  value = [
    for node in var.minio_cluster_config.nodes.haproxy : node.ip
  ]
}

output "harbor_minio_virtual_ip" {
  description = "MinIO virtual IP for Harbor"
  value       = var.minio_cluster_config.ha_virtual_ip
}
