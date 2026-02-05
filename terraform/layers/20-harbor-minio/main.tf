
module "minio_harbor" {
  source = "../../modules/service-ha/minio-distributed-cluster"

  topology_config   = var.harbor_minio_compute
  infra_config      = var.harbor_minio_infra
  service_domain    = local.service_domain
  vault_role_name   = local.vault_role_name
  vault_ca_cert_b64 = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
}

# This timer is to wait for MinIO Cluster to initialize the storage.
resource "time_sleep" "wait_for_minio_storage" {
  depends_on      = [module.minio_harbor]
  create_duration = "30s"
}

module "minio_harbor_system_config" {
  source     = "../../modules/configuration/minio-bucket-setup"
  depends_on = [time_sleep.wait_for_minio_storage]

  minio_tenants            = var.harbor_minio_tenants
  vault_secret_path_prefix = "secret/on-premise-gitlab-deployment/harbor/s3_credentials"
  minio_server_url         = "https://${var.harbor_minio_compute.haproxy_config.virtual_ip}:9000"
}
