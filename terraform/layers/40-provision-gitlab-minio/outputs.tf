
output "minio_server_url" {
  description = "The endpoint URL for the MinIO API"
  value       = local.minio_url
}

output "minio_tenants" {
  description = "Detailed configuration for each MinIO tenant"
  value       = var.gitlab_minio_tenants
}

output "minio_function_map" {
  description = "Map of logical functions to physical bucket names"
  value = {
    for bucket_name, config in var.gitlab_minio_tenants : config.function => bucket_name
  }
}
