
module "interface_planner" {
  source = "../../modules/cluster-provision/lb-interface-planner"

  node_config           = var.topology_cluster.load_balancer_config.nodes
  storage_pool_name     = var.topology_cluster.storage_pool_name
  svc_network           = local.svc_net
  network_infra         = local.infra
  svc_network_map       = var.svc_network_map
  service_segment_names = [for seg in var.network_service_segments : seg.name]
}

module "hypervisor_kvm" {
  source = "../../modules/cluster-provision/hypervisor-kvm-lb"

  credentials_vm              = local.credentials_vm_for_hypervisor
  lb_cluster_vm_config        = module.interface_planner.lb_cluster_vm_config
  lb_cluster_network_config   = module.interface_planner.lb_cluster_network_config
  lb_cluster_service_segments = var.network_service_segments
  network_infrastructure      = var.network_infrastructure_map
  create_networks             = false
}

module "ansible_inventory" {
  source = "../../modules/cluster-provision/lb-ansible-inventory"

  svc_identity = {
    service_name  = var.svc_identity.service_name
    domain_suffix = var.svc_identity.domain_suffix
  }
  network_service_segments = var.network_service_segments
  guest_nodes              = module.interface_planner.lb_cluster_vm_config.nodes
  template_vars_base       = var.ansible_generic_config.template_vars
}

module "ssh_manager" {
  source         = "../../modules/cluster-provision/ssh-manager"
  status_trigger = module.hypervisor_kvm.guest_status_trigger

  nodes          = module.interface_planner.nodes_list_for_ssh
  credentials_vm = local.credentials_vm_for_ssh
  config_name = {
    cluster_name    = var.svc_identity.cluster_name
    ssh_config_name = var.svc_identity.ssh_config
  }
}

module "ansible_runner" {
  source         = "../../modules/cluster-provision/ansible-runner"
  status_trigger = module.ssh_manager.ssh_access_ready_trigger

  inventory_data = module.ansible_inventory.ansible_inventory_data
  extra_vars     = local.ansible_extra_vars

  ansible_config = {
    ssh_config_path = module.ssh_manager.ssh_config_file_path
    root_path       = local.ansible.root_path
    inventory_file  = local.ansible.inventory_file
  }
}
