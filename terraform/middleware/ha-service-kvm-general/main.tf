
module "hypervisor_kvm" {
  source = "../../modules/cluster-provision/hypervisor-kvm"

  vm_config = local.vm_config

  create_networks        = false
  credentials            = local.vm_credentials_for_hypervisor
  libvirt_infrastructure = local.hypervisor_kvm_infrastructure
}

module "ssh_manager" {
  source         = "../../modules/cluster-provision/ssh-manager"
  status_trigger = module.hypervisor_kvm.vm_status_trigger

  nodes = [
    for k, v in local.flat_node_map : {
      key = k
      ip  = v.ip
    }
  ]

  config_name = {
    cluster_name    = var.svc_identity.cluster_name
    ssh_config_name = var.svc_identity.ssh_config
  }

  credentials_vm = local.vm_credentials_for_ssh
}

module "ansible_runner" {
  source         = "../../modules/cluster-provision/ansible-runner"
  status_trigger = module.ssh_manager.ssh_access_ready_trigger

  inventory_content = local.ansible_inventory_content
  credentials_vm    = local.vm_credentials_for_ssh

  ansible_config = {
    ssh_config_path = module.ssh_manager.ssh_config_file_path
    root_path       = local.ansible.root_path
    playbook_file   = local.ansible.playbook_file
    inventory_file  = local.ansible.inventory_file
  }

  extra_vars = nonsensitive(local.ansible_extra_vars)
  # Note: Use `nonsensitive()` if and only if in development. It must be disabled for production.
}
