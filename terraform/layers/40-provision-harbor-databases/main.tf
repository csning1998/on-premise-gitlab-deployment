
module "minio_harbor_config" {
  source = "../../modules/configuration/minio-bucket-setup"

  providers = {
    vault = vault.production
  }

  minio_tenants            = var.harbor_minio_tenants
  vault_secret_path_prefix = "on-premise-gitlab-deployment/harbor/s3_credentials"
  minio_server_url         = "https://${data.terraform_remote_state.minio_infra.outputs.service_vip}:${data.terraform_remote_state.minio_infra.outputs.minio_api_port}"
}

# Harbor DB Initialization
module "harbor_db_init" {
  source = "../../modules/configuration/patroni-init"

  pg_host = local.state.postgres.service_vip
  pg_port = local.pg_port

  pg_superuser          = "postgres"
  pg_superuser_password = local.pg_superuser_password

  databases = {
    (var.db_init_config.db_name) = {
      owner = var.db_init_config.db_user
    }
  }

  users = {
    (var.db_init_config.db_user) = {
      password = local.harbor_pg_db_password
      roles    = []
    }
  }
}
