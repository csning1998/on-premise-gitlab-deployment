
module "redis_harbor" {
  source = "../../modules/25-redis-ha"

  topology_config = var.harbor_redis_compute
  infra_config    = var.harbor_redis_infra
}
