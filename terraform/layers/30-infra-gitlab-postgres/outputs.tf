
output "service_vip" {
  description = "The virtual IP assigned to the Postgres service from Central LB topology."
  value       = module.context.primary_net_config.lb_config.vip
}

output "topology_cluster" {
  description = "The actual provisioned configuration for all Postgres and Etcd nodes."
  value       = module.infra_gitlab_postgres.cluster_nodes
}

output "connection_info" {
  description = "PostgreSQL load-balancer endpoint for L40 consumption."
  value = {
    host = module.context.primary_net_config.lb_config.vip
    port = module.context.primary_net_config.lb_config.ports["rw-proxy"].frontend_port
  }
}

output "observability_targets" {
  description = "Observability scrape endpoints for PostgreSQL and Etcd."
  value = {
    postgres_metrics_port = module.context.svc_network.ports["metrics"].frontend_port
    etcd_client_port      = module.context.tier_network_map["etcd"].ports["client"].frontend_port
    etcd_node_ips         = module.context.tier_network_map["etcd"].node_ips
  }
}
