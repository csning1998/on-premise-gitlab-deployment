
# Vault KV paths written by this layer, for documentation and cross-layer reference.
output "credential_paths" {
  description = "Mount-relative Vault KV paths of all generated credentials."
  value = {
    gitlab_postgres              = module.gitlab_postgres.path
    gitlab_redis                 = module.gitlab_redis.path
    gitlab_minio                 = module.gitlab_minio.path
    harbor_postgres              = module.harbor_postgres.path
    harbor_redis                 = module.harbor_redis.path
    harbor_minio                 = module.harbor_minio.path
    keycloak_frontend            = module.keycloak_server.path
    harbor_bootstrapper_frontend = module.harbor_bootstrapper.path
    gitlab_gitaly                = module.gitlab_app_gitaly.path
    gitlab_praefect_patroni      = module.gitlab_app_postgres.path
    gitlab_frontend              = module.gitlab_app_internal.path
    harbor_frontend              = module.harbor_app_internal.path
    observability_frontend       = module.observability_frontend.path
    observability_minio          = module.observability_minio.path
  }
}
