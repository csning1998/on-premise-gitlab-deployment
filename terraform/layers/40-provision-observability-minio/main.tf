
module "minio_observability_config" {
  source = "../../modules/configuration/minio-bucket-setup"

  providers = {
    vault = vault.production
  }

  minio_tenants            = var.observability_minio_tenants
  vault_secret_path_prefix = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/observability/app/s3_credentials"
  minio_server_url         = local.minio_url
}

module "minio_observability_prometheus_account" {
  source = "../../modules/configuration/minio-prometheus-account"

  providers = {
    vault.production = vault.production
  }

  user_name         = var.observability_minio_prometheus_account["observability-minio-prometheus"].user_name
  vault_secret_path = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/observability/app/minio_prometheus"
}
