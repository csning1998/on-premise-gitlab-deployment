
module "kubeadm_gitlab" {
  source = "../../modules/51-kubeadm-ha"

  topology_config = var.gitlab_kubeadm_compute
  infra_config    = var.gitlab_kubeadm_infra
}
