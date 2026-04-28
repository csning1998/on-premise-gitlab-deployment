
output "harbor_microk8s_ip_list" {
  description = "List of MicroK8s node IPs for Harbor"
  value       = local.ansible_template_vars.microk8s_cluster_ips
}

output "harbor_microk8s_virtual_ip" {
  description = "MicroK8s virtual IP for Harbor"
  value       = local.ansible_template_vars.microk8s_ingress_vip
}
