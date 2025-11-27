
output "minio_ip_list" {
  description = "List of MinIO node IPs"
  value = [
    for node in var.minio_cluster_config.nodes.minio : node.ip
  ]
}

output "minio_haproxy_ip_list" {
  description = "List of MinIO HAProxy node IPs"
  value = [
    for node in var.minio_cluster_config.nodes.haproxy : node.ip
  ]
}

output "minio_virtual_ip" {
  description = "MinIO virtual IP"
  value       = var.minio_cluster_config.ha_virtual_ip
}
