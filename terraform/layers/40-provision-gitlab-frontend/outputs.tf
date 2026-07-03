
output "issuer_name" {
  description = "The name of the Cert-Manager issuer provisioned in Layer 40"
  value       = module.platform_trust_engine.issuer_name
}

output "issuer_kind" {
  description = "The kind of the Cert-Manager issuer provisioned in Layer 40"
  value       = module.platform_trust_engine.issuer_kind
}

output "kubernetes_context" {
  description = "Kubeadm cluster connectivity data for L50 consumption"
  value = {
    service_vip      = local.state.kubeadm.service_vip
    cluster_name     = local.state.kubeadm.cluster_name
    topology_cluster = local.state.kubeadm.topology_cluster
  }
}
