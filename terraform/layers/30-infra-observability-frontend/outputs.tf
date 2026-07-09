
output "observability_microk8s_ip_list" {
  description = "List of MicroK8s node IPs for Observability."
  value       = local.ansible_template_vars.microk8s_cluster_ips
}

output "observability_microk8s_vip" {
  description = "MicroK8s virtual IP for Observability."
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

output "ingress_http_node_port" {
  description = "K8s ingress HTTP backend nodePort for L40/L50 consumption."
  value       = module.context.svc_network.ports["ingress-http"].backend_port
}

output "ingress_https_node_port" {
  description = "K8s ingress HTTPS backend nodePort for L40/L50 consumption."
  value       = module.context.svc_network.ports["ingress-https"].backend_port
}

output "vm_scrape_targets" {
  description = "VM-level observability scrape targets aggregated from L10 network topology for L40+ consumption."
  value = {
    haproxy_stats_port                  = local.network_central_lb.ports["stats"].frontend_port
    central_lb_ips                      = local.network_central_lb.node_ips
    keycloak_metrics_address            = "${local.network_keycloak.node_ips[0]}:${local.network_keycloak.ports["mgmt"].frontend_port}"
    keycloak_node_ip                    = local.network_keycloak.node_ips[0]
    harbor_bootstrapper_metrics_address = "${local.network_harbor_bootstrapper.node_ips[0]}:${local.network_harbor_bootstrapper.ports["metrics"].frontend_port}"
  }
}

output "node_exporter_targets" {
  description = "Node Exporter scrape targets for the Observability MicroK8s VM fleet."
  value = {
    ips  = local.ansible_template_vars.microk8s_cluster_ips
    port = module.context.node_exporter_port
  }
}
