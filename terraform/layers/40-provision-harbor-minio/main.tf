
module "minio_harbor_config" {
  source = "../../modules/configuration/minio-bucket-setup"

  providers = {
    vault = vault.production
  }

  minio_tenants            = var.harbor_minio_tenants
  vault_secret_path_prefix = "secret/on-premise-gitlab-deployment/harbor/s3_credentials"
  minio_server_url         = "https://${data.terraform_remote_state.minio_infra.outputs.service_vip}:${data.terraform_remote_state.minio_infra.outputs.minio_api_port}"
}
