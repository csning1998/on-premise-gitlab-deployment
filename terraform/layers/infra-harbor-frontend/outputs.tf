
output "harbor_microk8s_ip_list" {
  description = "List of MicroK8s node IPs for Harbor."
  value       = local.ansible_template_vars.microk8s_cluster_ips
}

output "harbor_microk8s_virtual_ip" {
  description = "MicroK8s virtual IP for Harbor."
  value       = local.ansible_template_vars.microk8s_ingress_vip
}

output "global_network_mtu" {
  description = "Global MTU for K8s pod network CNI configuration."
  value       = module.context.global_mtu
}

output "k8s_api_port" {
  description = "K8s API server frontend port for L40 consumption."
  value       = module.context.svc_network.ports["api-server"].frontend_port
}

output "node_exporter_targets" {
  description = "Node Exporter scrape targets for the Harbor MicroK8s VM fleet."
  value = {
    ips  = local.ansible_template_vars.microk8s_cluster_ips
    port = module.context.node_exporter_port
  }
}
