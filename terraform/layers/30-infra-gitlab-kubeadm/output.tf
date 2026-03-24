
output "service_vip" {
  description = "The virtual IP assigned to the Kubeadm entrypoint."
  value       = local.p_net_config.lb_config.vip
}

output "credentials_system" {
  description = "System-level access credentials for the cluster nodes."
  value       = local.sec_vm_creds
  sensitive   = true
}

output "kubernetes_config" {
  description = "Kubernetes cluster connection parameters."
  value       = local.ansible_template_vars
  sensitive   = true
}

output "topology_cluster" {
  description = "The full provisioned compute topology."
  value       = module.kubeadm_gitlab.cluster_nodes
}
