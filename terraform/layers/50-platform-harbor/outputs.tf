
output "trust_context" {
  description = "Cert-Manager issuer details for services to consume"
  value = {
    issuer_name = module.platform_trust_engine.issuer_name
    issuer_kind = module.platform_trust_engine.issuer_kind
  }
}

output "ingress_context" {
  description = "Ingress controller details"
  value = {
    class_name       = var.ingress_class_name
    load_balancer_ip = data.terraform_remote_state.microk8s_provision.outputs.harbor_microk8s_virtual_ip
    node_ports       = null
  }
}
