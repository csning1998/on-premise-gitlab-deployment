
output "service_vip" {
  description = "The virtual IP assigned to the MinIO service from Central LB topology."
  value       = module.context.primary_net_config.lb_config.vip
}

output "minio_api_port" {
  description = "The frontend port for MinIO API."
  value       = module.context.primary_net_config.lb_config.ports["api"].frontend_port
}

output "observability_minio_cluster_name" {
  description = "Observability MinIO cluster name."
  value       = module.context.svc_identity.cluster_name
}
