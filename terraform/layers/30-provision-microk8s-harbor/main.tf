
module "microk8s_harbor" {
  source = "../../modules/31-composition-microk8s-ha"

  microk8s_cluster_config = var.harbor_cluster_config
  libvirt_infrastructure  = var.harbor_infrastructure
}
