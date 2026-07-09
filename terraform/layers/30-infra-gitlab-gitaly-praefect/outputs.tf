
output "service_vip" {
  description = "The virtual IP of the primary tier."
  value       = module.context.primary_net_config.lb_config.vip
}

output "service_vips" {
  description = "The virtual IPs assigned to each service tier."
  value = {
    gitaly           = module.context.network_infrastructure_map["gitaly"].lb_config.vip
    praefect         = module.context.network_infrastructure_map["praefect"].lb_config.vip
    praefect-patroni = module.context.network_infrastructure_map["praefect-patroni"].lb_config.vip
  }
}

output "topology_cluster" {
  description = "The actual provisioned configuration for all nodes."
  value       = module.infra_gitlab_gitaly_praefect.cluster_nodes
}

output "praefect_connection_info" {
  description = "Praefect proxy endpoint for L40 consumption."
  value = {
    host = module.context.network_infrastructure_map["praefect"].lb_config.vip
    port = module.context.network_infrastructure_map["praefect"].lb_config.ports["proxy"].frontend_port
  }
}

output "gitaly_connection_info" {
  description = "Gitaly gRPC endpoint for L40 consumption."
  value = {
    host = module.context.network_infrastructure_map["gitaly"].lb_config.vip
    port = module.context.network_infrastructure_map["gitaly"].lb_config.ports["grpc"].frontend_port
  }
}

output "observability_targets" {
  description = "Observability scrape endpoints for Gitaly/Praefect components."
  value = {
    gitaly_metrics_port           = module.context.tier_network_map["gitaly"].ports["metrics"].frontend_port
    praefect_metrics_port         = module.context.tier_network_map["praefect"].ports["metrics"].frontend_port
    praefect_patroni_metrics_port = module.context.tier_network_map["praefect-patroni"].ports["metrics"].frontend_port
    praefect_patroni_etcd_port    = module.context.tier_network_map["praefect-patroni"].ports["etcd"].frontend_port
    gitaly_node_ips               = module.context.tier_network_map["gitaly"].node_ips
    praefect_node_ips             = module.context.tier_network_map["praefect"].node_ips
    praefect_patroni_node_ips     = module.context.tier_network_map["praefect-patroni"].node_ips
    node_exporter_port            = module.context.node_exporter_port
  }
}
