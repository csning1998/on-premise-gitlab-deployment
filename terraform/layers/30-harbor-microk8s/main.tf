
module "microk8s_harbor" {
  source = "../../modules/31-microk8s-ha"

  topology_config = var.harbor_microk8s_compute
  infra_config    = var.harbor_microk8s_infra
}
