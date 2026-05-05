
output "minio_server_url" {
  value = local.minio_url
}

output "postgres_connection_info" {
  value = {
    host     = local.postgres_vip
    port     = local.postgres_rw_port
    database = var.db_init_config.db_name
    username = var.db_init_config.db_user
  }
}

output "minio_function_map" {
  value = module.minio_harbor_config.minio_function_map
}
