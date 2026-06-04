
output "service_vip" {
  description = "The virtual IP assigned to the Kubeadm entrypoint."
  value       = module.context.primary_net_config.lb_config.vip
}

output "cluster_name" {
  description = "The name of the Cluster from the metadata."
  value       = module.context.svc_identity.cluster_name
}

output "credentials_system" {
  description = "System-level access credentials for the cluster nodes."
  value       = module.context.sec_vm_creds
  sensitive   = true
}

output "kubernetes_config" {
  description = "Kubernetes cluster connection parameters."
  value       = local.ansible_template_vars
  sensitive   = true
}

output "topology_cluster" {
  description = "The full provisioned compute topology."
  value       = module.infra_gitlab_frontend.cluster_nodes
}

output "ansible_inventory" {
  description = "The generated Ansible inventory content and file path."
  value       = module.infra_gitlab_frontend.ansible_inventory
}
