
module "minio_harbor" {
  source = "../../modules/27-minio-ha"

  topology_config = var.harbor_minio_compute
  infra_config    = var.harbor_minio_infra
}
