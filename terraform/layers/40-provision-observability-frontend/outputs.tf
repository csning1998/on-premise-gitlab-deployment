
output "trust_context" {
  description = "Cert-Manager issuer details provisioned by this layer"
  value = {
    issuer_name = module.platform_trust_engine.issuer_name
    issuer_kind = module.platform_trust_engine.issuer_kind
  }
}

output "ingress_context" {
  description = "Ingress controller details for downstream consumption"
  value = {
    load_balancer_ip = local.observability_vip
    http_node_port   = local.state.network.global_topology_network["observability"]["frontend"].ports["ingress-http"].backend_port
    https_node_port  = local.state.network.global_topology_network["observability"]["frontend"].ports["ingress-https"].backend_port
  }
}

output "cert_manager_info" {
  description = "Summary of Cert-Manager and Issuer installation"
  value = {
    namespace   = var.cert_manager_config.namespace
    issuer_name = module.platform_trust_engine.issuer_name
  }
}

output "reloader_helm_metadata" {
  description = "Detailed metadata of the deployed Reloader Helm release"
  value       = module.reloader.helm_release_metadata
}
