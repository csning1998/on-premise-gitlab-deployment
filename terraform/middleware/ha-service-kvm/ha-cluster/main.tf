
module "hypervisor_kvm" {
  count  = var.use_minio_hypervisor ? 0 : 1
  source = "../../../modules/cluster-provision/hypervisor-kvm"

  vm_config = {
    all_nodes_map = {
      for k, v in local.flat_node_map : k => {
        ip              = v.ip
        vcpu            = v.vcpu
        ram             = v.ram
        base_image_path = v.base_image_path
        data_disks      = v.data_disks
        network_tier    = v.network_tier
      }
    }
  }

  create_networks        = false
  credentials            = local.vm_credentials_for_hypervisor
  libvirt_infrastructure = local.hypervisor_kvm_infrastructure
}

module "hypervisor_kvm_minio" {
  count  = var.use_minio_hypervisor ? 1 : 0
  source = "../../../modules/cluster-provision/hypervisor-kvm-minio"

  vm_config = {
    all_nodes_map = {
      for k, v in local.flat_node_map : k => {
        ip              = v.ip
        vcpu            = v.vcpu
        ram             = v.ram
        base_image_path = v.base_image_path
        data_disks      = v.data_disks
        network_tier    = v.network_tier
      }
    }
  }

  create_networks        = false
  credentials            = local.vm_credentials_for_hypervisor
  libvirt_infrastructure = local.hypervisor_kvm_infrastructure
}

module "ssh_manager" {
  source         = "../../../modules/cluster-provision/ssh-manager"
  status_trigger = var.use_minio_hypervisor ? module.hypervisor_kvm_minio[0].vm_status_trigger : module.hypervisor_kvm[0].vm_status_trigger

  nodes = [
    for k, v in local.flat_node_map : {
      key = k
      ip  = v.ip
    }
  ]

  config_name = {
    cluster_name = var.cluster_name
  }

  credentials_vm = local.vm_credentials_for_ssh
}

module "ansible_runner" {
  source         = "../../../modules/cluster-provision/ansible-runner"
  status_trigger = module.ssh_manager.ssh_access_ready_trigger

  inventory_content = var.ansible_inventory_content
  credentials_vm    = local.vm_credentials_for_ssh

  ansible_config = {
    ssh_config_path = module.ssh_manager.ssh_config_file_path
    root_path       = local.ansible.root_path
    playbook_file   = local.ansible.playbook_file
    inventory_file  = local.ansible.inventory_file
  }

  extra_vars = var.ansible_extra_vars
}
