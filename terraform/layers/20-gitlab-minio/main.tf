
module "minio_gitlab" {
  source = "../../modules/27-composition-minio-ha"

  minio_cluster_config = var.minio_cluster_config
  minio_infrastructure = var.minio_infrastructure
}
