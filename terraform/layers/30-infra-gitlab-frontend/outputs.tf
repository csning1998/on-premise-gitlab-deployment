
output "service_vip" {
  description = "The virtual IP assigned to the Kubeadm entrypoint."
  value       = module.context.primary_net_config.lb_config.vip
}

output "cluster_name" {
  description = "The name of the Cluster from the metadata."
  value       = module.context.svc_identity.cluster_name
}

output "kubernetes_config" {
  description = "Kubernetes cluster connection parameters."
  value       = local.ansible_template_vars
  sensitive   = true
}

output "topology_cluster" {
  description = "The full provisioned compute topology."
  value       = module.infra_gitlab_frontend.cluster_nodes
}

output "global_network_mtu" {
  description = "Global MTU for K8s pod network CNI configuration."
  value       = module.context.global_mtu
}

output "k8s_api_port" {
  description = "K8s API server frontend port for L40 consumption."
  value       = module.context.svc_network.ports["api-server"].frontend_port
}

output "gitlab_ssh_port" {
  description = "GitLab SSH frontend port for L40/L50 consumption."
  value       = module.context.svc_network.ports["gitlab-ssh"].frontend_port
}

output "ingress_http_node_port" {
  description = "K8s ingress HTTP backend nodePort for L40/L50 consumption."
  value       = module.context.svc_network.ports["ingress-http"].backend_port
}

output "ingress_https_node_port" {
  description = "K8s ingress HTTPS backend nodePort for L40/L50 consumption."
  value       = module.context.svc_network.ports["ingress-https"].backend_port
}
