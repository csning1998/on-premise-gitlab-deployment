
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
    http_node_port   = local.state.microk8s_provision.ingress_http_node_port
    https_node_port  = local.state.microk8s_provision.ingress_https_node_port
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

output "vm_scrape_targets" {
  description = "VM-level observability scrape targets aggregated from L10 network topology for L40+ consumption."
  value       = local.state.microk8s_provision.vm_scrape_targets
}

output "vault_api_port" {
  description = "Vault API frontend port for L50 consumption."
  value       = local.state.vault_frontend.vault_api_port
}

output "observability_vip" {
  description = "Observability MicroK8s ingress VIP for same-tier L40 consumption."
  value       = local.observability_vip
}
