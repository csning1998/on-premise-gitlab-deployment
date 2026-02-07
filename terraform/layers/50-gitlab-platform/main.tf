
module "k8s_calico" {
  source     = "../../modules/kubernetes-addons/tigera-calico"
  pod_subnet = data.terraform_remote_state.cluster_provision.outputs.gitlab_pod_subnet
}

module "k8s_cert_manager" {
  source     = "../../modules/kubernetes-addons/cert-manager"
  depends_on = [module.k8s_calico]
}

module "k8s_metric_server" {
  source     = "../../modules/kubernetes-addons/metric-server"
  depends_on = [module.k8s_cert_manager]
}

module "k8s_ingress_nginx" {
  source     = "../../modules/kubernetes-addons/ingress-nginx"
  depends_on = [module.k8s_cert_manager]
}

module "k8s_storage_local_path" {
  source     = "../../modules/kubernetes-addons/local-path-provisioner"
  depends_on = [module.k8s_calico]
}
