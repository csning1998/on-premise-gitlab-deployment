
module "redis_gitlab" {
  source = "../../modules/25-redis-ha"

  topology_config = var.gitlab_redis_compute
  infra_config    = var.gitlab_redis_infra
}
