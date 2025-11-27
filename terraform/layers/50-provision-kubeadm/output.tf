
output "kubeadm_pod_subnet" {
  description = "The CIDR for the Pod network."
  value       = var.kubeadm_cluster_config.pod_subnet
}

output "kubeconfig_content" {
  description = "The content of the kubeconfig file."
  value       = lookup(data.external.fetched_kubeconfig.result, "content", "kubeconfig-not-found")
  sensitive   = true
}
