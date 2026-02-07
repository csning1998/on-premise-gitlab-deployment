
module "kubeadm_gitlab" {
  source = "../../modules/service-ha/kubeadm-cluster"

  topology_config = var.gitlab_kubeadm_compute
  infra_config    = var.gitlab_kubeadm_infra
}
