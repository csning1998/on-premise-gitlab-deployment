
output "harbor_microk8s_ip_list" {
  description = "List of MicroK8s node IPs for Harbor"
  value       = local.ansible_template_vars.microk8s_cluster_ips
}

output "harbor_microk8s_virtual_ip" {
  description = "MicroK8s virtual IP for Harbor"
  value       = local.ansible_template_vars.microk8s_ingress_vip
}

output "ansible_inventory" {
  description = "The generated Ansible inventory content and file path."
  value       = module.infra_harbor_frontend.ansible_inventory
}
