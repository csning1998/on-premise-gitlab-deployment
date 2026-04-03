
# Dynamically generate the CA Bundle for Provider Trust (to resolve SSL unknown authority)
resource "local_file" "minio_ca_bundle" {
  content  = vault_pki_secret_backend_cert.gitlab_db_client.ca_chain
  filename = "${path.module}/tls/minio-ca-bundle.crt"
}

module "minio_gitlab_config" {
  source = "../../modules/configuration/minio-bucket-setup"

  providers = {
    vault = vault.production
  }

  minio_tenants            = var.gitlab_minio_tenants
  vault_secret_path_prefix = "on-premise-gitlab-deployment/gitlab/app/s3_credentials"
  minio_server_url         = "https://${data.terraform_remote_state.minio.outputs.service_vip}:${data.terraform_remote_state.minio.outputs.minio_api_port}"
}
