
output "service_vip" {
  description = "The virtual IP assigned to the MinIO service from Central LB topology."
  value       = module.context.primary_net_config.lb_config.vip
}

output "minio_api_port" {
  description = "The frontend port for MinIO API."
  value       = module.context.primary_net_config.lb_config.ports["api"].frontend_port
}

output "harbor_minio_cluster_name" {
  description = "Harbor MinIO cluster name."
  value       = module.context.svc_identity.cluster_name
}

output "connection_info" {
  description = "MinIO load-balancer endpoint for L40 consumption."
  value = {
    host = module.context.primary_net_config.lb_config.vip
    port = module.context.primary_net_config.lb_config.ports["api"].frontend_port
  }
}
