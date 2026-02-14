
module "central_lb_cluster" {
  source = "../../modules/service-ha/load-balancer-cluster"

  topology_config = {
    cluster_name      = local.cluster_name
    storage_pool_name = local.storage_pool_name

    load_balancer_config = {
      nodes = local.nodes_configuration
    }
  }

  network_config = {
    network = {
      nat = {
        gateway = local.infra_network.nat.gateway
        cidrv4  = local.infra_network.nat.cidrv4
        dhcp    = local.infra_network.nat.dhcp
      }
      hostonly = {
        gateway = local.infra_network.hostonly.gateway
        cidrv4  = local.infra_network.hostonly.cidrv4
      }
    }
    allowed_subnet = local.allowed_subnet
  }

  service_segments    = local.hydrated_service_segments
  service_domain      = local.domain_suffix
  vm_credentials      = local.vm_credentials
  haproxy_credentials = local.haproxy_credentials

  network_identity = {
    nat_net_name         = local.infra_network.nat.name_network
    nat_bridge_name      = local.infra_network.nat.name_bridge
    hostonly_net_name    = local.infra_network.hostonly.name_network
    hostonly_bridge_name = local.infra_network.hostonly.name_bridge
  }
}
