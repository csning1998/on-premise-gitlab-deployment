
module "k8s_calico" {
  source     = "../../modules/61-kubeadm-tigera-calico"
  pod_subnet = data.terraform_remote_state.cluster_provision.outputs.kubeadm_pod_subnet
}

module "k8s_metric_server" {
  source     = "../../modules/62-kubeadm-metric-server"
  depends_on = [module.k8s_calico]
}

module "k8s_ingress_nginx" {
  source     = "../../modules/63-kubeadm-ingress-nginx"
  depends_on = [module.k8s_calico]
}

module "k8s_dashboard" {
  source             = "../../modules/64-kubeadm-dashboard"
  dashboard_hostname = "dashboard.k8s.local"
  depends_on = [
    module.k8s_calico,
    module.k8s_ingress_nginx
  ]
}
