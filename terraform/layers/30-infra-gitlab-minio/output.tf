
output "service_vip" {
  description = "The virtual IP assigned to the MinIO service from Central LB topology."
  value       = local.p_net_config.lb_config.vip
}

output "minio_api_port" {
  description = "The frontend port for MinIO API."
  value       = local.p_net_config.lb_config.ports["api"].frontend_port
}

output "credentials_system" {
  description = "System-level access credentials for the cluster nodes."
  value       = local.sec_system_creds
  sensitive   = true
}

output "gitlab_minio_cluster_name" {
  description = "GitLab MinIO cluster name."
  value       = local.svc_identity.cluster_name
}
