
output "postgres_connection_info" {
  description = "Postgres primary proxy connection info for L50 consumption"
  value       = local.state.postgres.connection_info
}

output "minio_server_url" {
  description = "The endpoint URL for the MinIO API"
  value       = local.minio_url
}

output "minio_tenants" {
  description = "Detailed configuration for each MinIO tenant"
  value       = var.harbor_minio_tenants
}

output "minio_function_map" {
  description = "Map of logical functions to physical bucket names"
  value = {
    for bucket_name, config in var.harbor_minio_tenants : bucket_name => bucket_name
  }
}

output "redis_connection_info" {
  description = "Redis connection info for Layer 50 credentials"
  value       = local.state.redis.connection_info
}

output "minio_connection_info" {
  description = "MinIO connection info for L50 consumption"
  value       = local.state.minio.connection_info
}

output "minio_credentials" {
  description = "Credentials for MinIO buckets"
  value       = module.minio_harbor_config.service_accounts
  sensitive   = true
}

output "observability_targets" {
  description = "Aggregated observability metrics ports and IPs for L50"
  value = {
    postgres_exporter_port = local.state.postgres.observability_targets.postgres_metrics_port
    postgres_ips           = local.state.postgres.observability_targets.postgres_node_ips
    etcd_client_port       = local.state.postgres.observability_targets.etcd_client_port
    etcd_ips               = local.state.postgres.observability_targets.etcd_node_ips
    redis_exporter_port    = local.state.redis.observability_targets.redis_metrics_port
    redis_ips              = local.state.redis.observability_targets.redis_node_ips
    minio_metrics_port     = local.state.minio.observability_targets.minio_metrics_port
    minio_ips              = local.state.minio.observability_targets.minio_node_ips
  }
}
