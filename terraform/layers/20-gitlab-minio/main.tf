
module "minio_gitlab" {
  source = "../../modules/27-minio-ha"

  topology_config = var.gitlab_minio_compute
  infra_config    = var.gitlab_minio_infra
}
