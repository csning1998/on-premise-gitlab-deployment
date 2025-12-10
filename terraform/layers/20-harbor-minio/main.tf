
module "minio_harbor" {
  source = "../../modules/27-minio-ha"

  topology_config = var.harbor_minio_compute
  infra_config    = var.harbor_minio_infra

  vault_role_name   = "harbor-minio"
  vault_ca_cert_b64 = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
}
