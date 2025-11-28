
output "gitlab_pod_subnet" {
  description = "The CIDR for the Pod network."
  value       = var.gitlab_cluster_config.pod_subnet
}

output "gitlab_kubeadm_master_ip_list" {
  description = "List of kubeadm master node IPs for Gitlab"
  value = [
    for node in var.gitlab_cluster_config.nodes.masters : node.ip
  ]
}

output "gitlab_kubeadm_worker_ip_list" {
  description = "List of kubeadm worker node IPs for Gitlab"
  value = [
    for node in var.gitlab_cluster_config.nodes.workers : node.ip
  ]
}

output "gitlab_kubeadm_virtual_ip" {
  description = "kubeadm virtual IP for Gitlab"
  value       = var.gitlab_cluster_config.ha_virtual_ip
}
