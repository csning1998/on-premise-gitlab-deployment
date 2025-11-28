
module "postgres_gitlab" {
  source = "../../modules/21-postgres-ha"

  topology_config = var.gitlab_postgres_compute
  infra_config    = var.gitlab_postgres_infra
}
