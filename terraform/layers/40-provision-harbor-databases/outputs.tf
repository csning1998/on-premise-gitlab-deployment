
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

output "postgres_connection_info" {
  description = "Postgres connection info for Layer 50 credentials"
  value = {
    host     = local.postgres_vip
    port     = local.postgres_rw_port
    username = var.db_init_config.db_user
    database = var.db_init_config.db_name
  }
}

output "postgres_client_cert_b64" {
  description = "Postgres client certificate for Layer 50 credentials"
  value = {
    crt_b64 = base64encode(vault_pki_secret_backend_cert.harbor_db_client.certificate)
    key_b64 = base64encode(vault_pki_secret_backend_cert.harbor_db_client.private_key)
    ca_b64  = base64encode(vault_pki_secret_backend_cert.harbor_db_client.ca_chain)
  }
  sensitive = true
}

output "redis_connection_info" {
  description = "Redis connection info for Layer 50 credentials"
  value = {
    host = local.state.network["core-harbor-redis"].lb_config.vip
    port = local.state.network["core-harbor-redis"].lb_config.ports["main"].frontend_port
  }
}

output "minio_credentials" {
  description = "Credentials for MinIO buckets"
  value       = module.minio_harbor_config.service_accounts
  sensitive   = true
}
