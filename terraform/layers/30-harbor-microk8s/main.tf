
module "microk8s_harbor" {
  source = "../../modules/service-ha/microk8s-cluster"

  topology_config = var.harbor_microk8s_compute
  infra_config    = var.harbor_microk8s_infra
}
