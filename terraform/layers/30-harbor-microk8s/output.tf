
output "harbor_microk8s_ip_list" {
  description = "List of MicroK8s node IPs for Harbor"
  value       = [for node in var.harbor_microk8s_compute.nodes : node.ip]
}

output "harbor_microk8s_virtual_ip" {
  description = "MicroK8s virtual IP for Harbor"
  value       = var.harbor_microk8s_compute.ha_config.virtual_ip
}

output "kubeconfig_content" {
  description = "The content of the Kubeconfig file fetched from the cluster."
  value       = module.microk8s_harbor.kubeconfig_content
  sensitive   = true
}
