
output "harbor_microk8s_ip_list" {
  description = "List of MicroK8s node IPs for Harbor"
  value = [
    for node in var.harbor_cluster_config.nodes.microk8s : node.ip
  ]
}

output "harbor_microk8s_virtual_ip" {
  description = "MicroK8s virtual IP for Harbor"
  value       = var.harbor_cluster_config.ha_virtual_ip
}
