
module "central_lb_cluster" {

  source = "../../middleware/ha-service-kvm-central-lb"
  svc_identity = merge(local.svc_identity, {
    service_name  = local.svc_cluster_name
    domain_suffix = local.svc_fqdn
  })

  topology_cluster = {
    cluster_name      = local.svc_cluster_name
    storage_pool_name = local.storage_pool_name

    load_balancer_config = {
      nodes = local.topology_nodes
    }
  }

  svc_network_map = local.network_map

  # Secrets & PKI
  security_pki_bundle_b64 = local.pki_global_ca_b64
  credentials_vm          = local.sec_vm_creds
  credentials_application = local.sec_haproxy_creds

  # Infrastructure Setup (Networks are managed by 04-network-topology layer)
  network_infrastructure_map = {
    (local.svc_cluster_name) = local.net_lb_config
  }
  network_service_segments = local.net_service_segments

  # Embedded Ansible Configurations
  ansible_generic_config = {
    template_vars = local.ansible_template_vars
    extra_vars    = local.ansible_extra_vars
  }
}
