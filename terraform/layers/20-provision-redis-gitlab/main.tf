
module "redis_gitlab" {
  source = "../../modules/25-composition-redis-ha"

  redis_cluster_config = var.redis_cluster_config
  redis_infrastructure = var.redis_infrastructure
}
