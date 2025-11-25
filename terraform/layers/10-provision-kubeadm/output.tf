
output "kubeadm_pod_subnet" {
  description = "The CIDR for the Pod network."
  value       = var.kubeadm_cluster_config.pod_subnet
}
