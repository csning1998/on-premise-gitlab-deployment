
module "central_lb_cluster" {

  source = "../../middleware/ha-service-kvm/central-load-balancer"

  topology_cluster = {
    cluster_name      = local.svc_cluster_name
    storage_pool_name = local.storage_pool_name

    load_balancer_config = {
      nodes = local.topology_nodes
    }
  }

  network_parameters = {
    network = {
      nat = {
        gateway = local.net_lb_config.nat.gateway
        cidrv4  = local.net_lb_config.nat.cidr
        dhcp    = local.net_lb_config.nat.dhcp
      }
      hostonly = {
        gateway = local.net_lb_config.hostonly.gateway
        cidrv4  = local.net_lb_config.hostonly.cidr
      }
    }
    access_scope = local.net_access_scope
  }

  security_pki_bundle      = local.pki_global_ca
  network_service_segments = local.net_service_segments
  service_fqdn             = local.svc_fqdn
  credentials_vm           = local.sec_vm_creds
  credentials_application  = local.sec_haproxy_creds
  network_infrastructure   = local.net_infrastructure

  network_bindings = {
    nat_net_name         = local.net_lb_config.nat.name
    nat_bridge_name      = local.net_lb_config.nat.bridge_name
    hostonly_net_name    = local.net_lb_config.hostonly.name
    hostonly_bridge_name = local.net_lb_config.hostonly.bridge_name
  }
}
