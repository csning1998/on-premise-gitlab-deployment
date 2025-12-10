
module "minio_gitlab" {
  source = "../../modules/27-minio-ha"

  topology_config = var.gitlab_minio_compute
  infra_config    = var.gitlab_minio_infra

  vault_role_name   = "gitlab-minio"
  vault_ca_cert_b64 = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
}
