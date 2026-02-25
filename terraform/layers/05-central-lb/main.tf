
module "central_lb_cluster" {

  source = "../../middleware/ha-service-kvm-central-lb"
  svc_identity = merge(local.svc_identity, {
    service_name = local.svc_name
  })

  topology_cluster = {
    cluster_name      = local.svc_cluster_name
    storage_pool_name = local.storage_pool_name

    load_balancer_config = {
      nodes = local.topology_nodes
    }
  }

  # Secrets & PKI
  security_pki_bundle     = local.pki_global_ca
  credentials_vm          = local.sec_vm_creds
  credentials_application = local.sec_haproxy_creds

  # Infrastructure Setup (Networks are managed by 04-network-topology layer)
  network_infrastructure_map = {
    (local.svc_name) = local.net_lb_config
  }
  network_service_segments = local.net_service_segments

  # Embedded Ansible Configurations
  ansible_inventory_template_file = "inventory-load-balancer-cluster.yaml.tftpl"
  ansible_playbook_file           = "10-provision-core-services.yaml"
  ansible_template_vars           = local.ansible_template_vars
  ansible_extra_vars              = local.ansible_extra_vars
}
