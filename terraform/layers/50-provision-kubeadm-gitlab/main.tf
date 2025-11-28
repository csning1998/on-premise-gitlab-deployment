
module "kubeadm_gitlab" {
  source = "../../modules/51-conposition-kubeadm-ha"

  kubeadm_cluster_config = var.gitlab_cluster_config
  libvirt_infrastructure = var.gitlab_infrastructure
}
