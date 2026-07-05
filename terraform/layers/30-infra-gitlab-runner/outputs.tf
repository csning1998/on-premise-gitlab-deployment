
output "runner_microk8s_ip_list" {
  description = "List of MicroK8s node IPs for GitLab Runner."
  value       = local.ansible_template_config.microk8s_cluster_ips
}

output "runner_microk8s_vip" {
  description = "MicroK8s virtual IP for GitLab Runner."
  value       = local.ansible_template_config.microk8s_ingress_vip
}

output "global_network_mtu" {
  description = "Global MTU for K8s pod network CNI configuration."
  value       = module.context.global_mtu
}

output "k8s_api_port" {
  description = "K8s API server frontend port for L40 consumption."
  value       = module.context.svc_network.ports["api-server"].frontend_port
}
