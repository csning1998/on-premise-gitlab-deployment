
module "minio_gitlab_config" {
  source = "../../modules/configuration/minio-bucket-setup"

  providers = {
    vault = vault.production
  }

  minio_tenants            = var.gitlab_minio_tenants
  vault_secret_path_prefix = "on-premise-gitlab-deployment/gitlab/app/s3_credentials"
  minio_server_url         = local.minio_url
}
