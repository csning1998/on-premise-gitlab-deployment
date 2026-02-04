
module "k8s_calico" {
  source     = "../../modules/41-kubeadm-tigera-calico"
  pod_subnet = data.terraform_remote_state.cluster_provision.outputs.gitlab_pod_subnet
}

module "k8s_cert_manager" {
  source     = "../../modules/45-kubeadm-cert-manager"
  depends_on = [module.k8s_calico]
}

module "k8s_metric_server" {
  source     = "../../modules/42-kubeadm-metric-server"
  depends_on = [module.k8s_cert_manager]
}

module "k8s_ingress_nginx" {
  source     = "../../modules/43-kubeadm-ingress-nginx"
  depends_on = [module.k8s_cert_manager]
}

module "k8s_storage_local_path" {
  source     = "../../modules/46-kubeadm-storage-local-path"
  depends_on = [module.k8s_calico]
}
