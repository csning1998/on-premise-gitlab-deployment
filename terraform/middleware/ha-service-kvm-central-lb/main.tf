
module "hypervisor_kvm" {
  source = "../../modules/cluster-provision/hypervisor-kvm-lb"

  credentials_vm              = local.credentials_vm_for_hypervisor
  lb_cluster_vm_config        = local.lb_cluster_vm_config
  lb_cluster_network_config   = local.lb_cluster_network_config
  lb_cluster_service_segments = var.network_service_segments
  network_infrastructure      = var.network_infrastructure
  create_networks             = false
}

module "ssh_manager" {
  source         = "../../modules/cluster-provision/ssh-manager"
  status_trigger = module.hypervisor_kvm.vm_status_trigger

  nodes          = local.nodes_list_for_ssh
  credentials_vm = local.credentials_vm_for_ssh
  config_name = {
    cluster_name = var.topology_cluster.cluster_name
  }
}

module "ansible_runner" {
  source         = "../../modules/cluster-provision/ansible-runner"
  status_trigger = module.ssh_manager.ssh_access_ready_trigger

  inventory_content = local.ansible.inventory_contents
  credentials_vm    = local.credentials_vm_for_ssh
  extra_vars        = local.ansible_extra_vars

  ansible_config = {
    ssh_config_path = module.ssh_manager.ssh_config_file_path
    root_path       = local.ansible.root_path
    playbook_file   = local.ansible.playbook_file
    inventory_file  = local.ansible.inventory_file
  }
}
