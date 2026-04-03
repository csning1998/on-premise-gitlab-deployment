
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

output "postgres_connection_info" {
  description = "Postgres connection info for Layer 50 credentials"
  value = {
    host     = local.postgres_vip
    port     = local.postgres_rw_port
    username = postgresql_role.gitlab.name
    password = postgresql_role.gitlab.password
    database = postgresql_database.gitlabhq_production.name
  }
  sensitive = true
}

output "postgres_client_cert" {
  description = "Postgres client certificate for Layer 50 credentials"
  value = {
    crt = base64encode(vault_pki_secret_backend_cert.gitlab_db_client.certificate)
    key = base64encode(vault_pki_secret_backend_cert.gitlab_db_client.private_key)
    ca  = base64encode(vault_pki_secret_backend_cert.gitlab_db_client.ca_chain)
  }
  sensitive = true
}

output "redis_connection_info" {
  description = "Redis connection info for Layer 50 credentials"
  value = {
    host     = local.state.network["core-gitlab-redis"].lb_config.vip
    port     = local.state.network["core-gitlab-redis"].lb_config.ports["main"].frontend_port
    password = data.vault_kv_secret_v2.db_vars.data["redis_requirepass"]
  }
  sensitive = true
}
