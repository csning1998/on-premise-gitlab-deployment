
output "trust_context" {
  description = "Cert-Manager issuer details for services to consume"
  value = {
    issuer_name = module.platform_trust_engine.issuer_name
    issuer_kind = module.platform_trust_engine.issuer_kind
  }
}

output "ingress_context" {
  description = "Ingress controller details formatted for SSoT consumption"
  value = {
    load_balancer_ip = local.state.kubeadm.service_vip
    http_node_port   = local.state.metadata.global_topology_network["gitlab"]["frontend"].ports["ingress-http"].backend_port
    https_node_port  = local.state.metadata.global_topology_network["gitlab"]["frontend"].ports["ingress-https"].backend_port
  }
}

output "cert_manager_info" {
  description = "Summary of Cert-Manager and Issuer installation"
  value = {
    namespace   = var.cert_manager_config.namespace
    issuer_name = module.platform_trust_engine.issuer_name
  }
}
