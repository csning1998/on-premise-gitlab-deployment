
output "service_vip" {
  description = "The virtual IP assigned to the MinIO service from Central LB topology."
  value       = local.net_service_vip
}

output "credentials_system" {
  description = "System-level access credentials for the cluster nodes."
  value       = local.sec_system_creds
  sensitive   = true
}

output "credentials_db" {
  description = "Database-level credentials for MinIO."
  value       = local.sec_db_creds
  sensitive   = true
}

output "gitlab_minio_cluster_name" {
  description = "GitLab MinIO cluster name."
  value       = local.svc_cluster_name
}

output "gitlab_minio_tenants" {
  description = "GitLab MinIO tenants"
  value       = var.gitlab_minio_tenants
}
