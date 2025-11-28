
module "postgres_harbor" {
  source = "../../modules/21-postgres-ha"

  topology_config = var.harbor_postgres_compute
  infra_config    = var.harbor_postgres_infra
}
