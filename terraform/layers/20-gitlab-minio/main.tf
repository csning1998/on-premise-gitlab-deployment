
module "minio_gitlab" {
  source = "../../modules/27-minio-ha"

  topology_config   = var.gitlab_minio_compute
  infra_config      = var.gitlab_minio_infra
  service_domain    = local.service_domain
  vault_role_name   = local.vault_role_name
  vault_ca_cert_b64 = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
}

# This timer is to wait for MinIO Cluster to initialize the storage.
resource "time_sleep" "wait_for_minio_storage" {
  depends_on      = [module.minio_gitlab]
  create_duration = "30s"
}

module "minio_gitlab_config" {
  source     = "../../modules/28-minio-config"
  depends_on = [time_sleep.wait_for_minio_storage]

  minio_tenants            = var.gitlab_minio_tenants
  vault_secret_path_prefix = "secret/on-premise-gitlab-deployment/gitlab/s3_credentials"
  minio_server_url         = "https://${var.gitlab_minio_compute.haproxy_config.virtual_ip}:9000"
}

