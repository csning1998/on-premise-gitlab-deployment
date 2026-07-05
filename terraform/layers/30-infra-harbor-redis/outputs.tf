
output "service_vip" {
  description = "The virtual IP assigned to the Redis service from Central LB topology."
  value       = module.context.primary_net_config.lb_config.vip
}

output "topology_cluster" {
  description = "The actual provisioned configuration for all Redis nodes."
  value       = module.infra_harbor_redis.cluster_nodes
}

output "connection_info" {
  description = "Redis load-balancer endpoint for L40 consumption."
  value = {
    host = module.context.primary_net_config.lb_config.vip
    port = module.context.primary_net_config.lb_config.ports["main"].frontend_port
  }
}

output "observability_targets" {
  description = "Observability scrape endpoint for Harbor Redis."
  value = {
    redis_metrics_port = module.context.svc_network.ports["metrics"].frontend_port
  }
}
