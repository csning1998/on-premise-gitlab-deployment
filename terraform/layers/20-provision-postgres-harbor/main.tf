
module "postgres_harbor" {
  source = "../../modules/21-composition-postgres-ha"

  postgres_cluster_config = var.postgres_cluster_config
  postgres_infrastructure = var.postgres_infrastructure
}
