
module "central_lb_cluster" {

  source = "../../middleware/ha-service-kvm/central-load-balancer"

  topology_cluster = {
    cluster_name      = local.cluster_name
    storage_pool_name = local.storage_pool_name

    load_balancer_config = {
      nodes = local.nodes_configuration
    }
  }

  network_parameters = {
    network = {
      nat = {
        gateway = local.lb_network_config.nat.gateway
        cidrv4  = local.lb_network_config.nat.cidr
        dhcp    = local.lb_network_config.nat.dhcp
      }
      hostonly = {
        gateway = local.lb_network_config.hostonly.gateway
        cidrv4  = local.lb_network_config.hostonly.cidr
      }
    }
    access_scope = local.network_access_scope
  }

  security_pki_bundle      = local.vault_pki
  network_service_segments = local.network_service_segments
  service_fqdn             = local.domain_suffix
  credentials_vm           = local.credentials_vm
  credentials_application  = local.credentials_haproxy
  network_infrastructure   = local.network_infrastructure

  network_bindings = {
    nat_net_name         = local.lb_network_config.nat.name
    nat_bridge_name      = local.lb_network_config.nat.bridge_name
    hostonly_net_name    = local.lb_network_config.hostonly.name
    hostonly_bridge_name = local.lb_network_config.hostonly.bridge_name
  }
}
