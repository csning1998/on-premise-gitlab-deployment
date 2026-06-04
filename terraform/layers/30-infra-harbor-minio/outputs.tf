
output "service_vip" {
  description = "The virtual IP assigned to the MinIO service from Central LB topology."
  value       = module.context.primary_net_config.lb_config.vip
}

output "minio_api_port" {
  description = "The frontend port for MinIO API."
  value       = module.context.primary_net_config.lb_config.ports["api"].frontend_port
}

output "credentials_system" {
  description = "System-level access credentials for the cluster nodes."
  value       = module.context.sec_vm_creds
  sensitive   = true
}

output "harbor_minio_cluster_name" {
  description = "Harbor MinIO cluster name."
  value       = module.context.svc_identity.cluster_name
}

output "ansible_inventory" {
  description = "The generated Ansible inventory content and file path."
  value       = module.infra_harbor_minio.ansible_inventory
}
