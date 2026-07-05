
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
    global_network_mtu  = local.state.runner_cluster.global_network_mtu
    vault_api_port      = local.state.vault_frontend.vault_api_port
    vip_gitlab_frontend = data.terraform_remote_state.gitlab_frontend.outputs.service_vip
  }
}
