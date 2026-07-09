
output "minio_server_url" {
  description = "The endpoint URL for the observability MinIO API"
  value       = local.minio_url
}

output "minio_tenants" {
  description = "Detailed configuration for each observability MinIO tenant"
  value       = var.observability_minio_tenants
}

output "minio_function_map" {
  description = "Map of logical functions to physical bucket names"
  value = {
    for bucket_name, config in var.observability_minio_tenants : config.function => bucket_name
  }
}

output "minio_credentials" {
  description = "Generated service account credentials for each observability bucket"
  value       = module.minio_observability_config.service_accounts
  sensitive   = true
}

output "minio_api_port" {
  description = "Pass-through MinIO API port from L30 infra state for L50 consumption"
  value       = local.state.minio.minio_api_port
}

output "observability_targets" {
  description = "Observability scrape endpoint for Observability MinIO."
  value       = local.state.minio.observability_targets
}
