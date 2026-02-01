
output "gitlab_pod_subnet" {
  description = "The CIDR for the Pod network."
  value       = var.gitlab_kubeadm_compute.pod_subnet
}

output "gitlab_kubeadm_master_ip_list" {
  description = "List of kubeadm master node IPs for Gitlab"
  value       = [for node in var.gitlab_kubeadm_compute.kubeadm_config.master_nodes : node.ip]
}

output "gitlab_kubeadm_worker_ip_list" {
  description = "List of kubeadm worker node IPs for Gitlab"
  value       = [for node in var.gitlab_kubeadm_compute.kubeadm_config.worker_nodes : node.ip]
}

output "gitlab_kubeadm_virtual_ip" {
  description = "kubeadm virtual IP for Gitlab"
  value       = var.gitlab_kubeadm_compute.haproxy_config.virtual_ip
}

output "kubeconfig_content" {
  description = "The content of the Kubeconfig file fetched from the cluster."
  value       = module.kubeadm_gitlab.kubeconfig_content
  sensitive   = true
}
