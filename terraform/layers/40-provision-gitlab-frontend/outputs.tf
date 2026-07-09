
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

output "has_praefect" {
  description = "True if Praefect cluster nodes are provisioned; consumed by L50 for Gitaly token and node selection."
  value       = local._has_praefect
}

output "gitaly_endpoint" {
  description = "Gitaly or Praefect gRPC endpoint for GitLab storage backend; Praefect takes precedence if provisioned."
  value       = local._has_praefect ? "${local._praefect_vip}:${local._praefect_port}" : "${local._gitaly_vip}:${local._gitaly_port}"
}

output "network_context" {
  description = "Aggregated network and port configurations for L50 consumption"
  value = {
    global_network_mtu      = local.state.kubeadm.global_network_mtu
    k8s_api_port            = local.state.kubeadm.k8s_api_port
    gitlab_ssh_port         = local.state.kubeadm.gitlab_ssh_port
    ingress_http_node_port  = local.state.kubeadm.ingress_http_node_port
    ingress_https_node_port = local.state.kubeadm.ingress_https_node_port
    vault_api_port          = local.state.vault_frontend.vault_api_port
  }
}

output "gitaly_observability_targets" {
  description = "Observability endpoints for Gitaly and Praefect."
  value       = local.state.gitaly_praefect.observability_targets
}

output "kubeadm_node_exporter_targets" {
  description = "Node Exporter scrape targets for the Kubeadm VM fleet."
  value       = local.state.kubeadm.node_exporter_targets
}
