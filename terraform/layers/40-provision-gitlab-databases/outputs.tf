
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


output "redis_connection_info" {
  description = "Redis connection info for Layer 50 credentials"
  value = {
    host = local.state.network["core-gitlab-redis"].lb_config.vip
    port = local.state.network["core-gitlab-redis"].lb_config.ports["main"].frontend_port
  }
}

output "minio_credentials" {
  description = "Credentials for MinIO buckets"
  value       = module.minio_gitlab_config.service_accounts
  sensitive   = true
}
