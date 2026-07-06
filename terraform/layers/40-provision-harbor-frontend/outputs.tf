
output "issuer_name" {
  description = "The name of the Cert-Manager issuer provisioned in Layer 40"
  value       = module.platform_trust_engine.issuer_name
}

output "issuer_kind" {
  description = "The kind of the Cert-Manager issuer provisioned in Layer 40"
  value       = module.platform_trust_engine.issuer_kind
}

output "network_context" {
  description = "Aggregated network and port configurations for L50 consumption"
  value = {
    global_network_mtu = local.state.microk8s_provision.global_network_mtu
    k8s_api_port       = local.state.microk8s_provision.k8s_api_port
    vault_api_port     = local.state.vault_frontend.vault_api_port
  }
}
