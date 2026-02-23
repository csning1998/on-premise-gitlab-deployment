
module "hypervisor_kvm" {
  source = "../../cluster-provision/hypervisor-kvm-lb"

  lb_cluster_service_segments = var.network_service_segments
  network_infrastructure      = var.network_infrastructure
  credentials_vm              = local.credentials_vm_for_hypervisor
  create_networks             = false

  lb_cluster_vm_config = {
    storage_pool_name = var.topology_cluster.storage_pool_name
    nodes             = var.topology_cluster.load_balancer_config.nodes
  }

  lb_cluster_network_config = {
    network = {
      nat = {
        name_network = var.network_bindings.nat_net_name
        name_bridge  = var.network_bindings.nat_bridge_name
        mode         = "nat"
        ips = {
          address = var.network_parameters.network.nat.gateway
          prefix  = tonumber(split("/", var.network_parameters.network.nat.cidrv4)[1])
          dhcp    = var.network_parameters.network.nat.dhcp
        }
      }
      hostonly = {
        name_network = var.network_bindings.hostonly_net_name
        name_bridge  = var.network_bindings.hostonly_bridge_name
        mode         = "route"
        ips = {
          address = var.network_parameters.network.hostonly.gateway
          prefix  = tonumber(split("/", var.network_parameters.network.hostonly.cidrv4)[1])
          dhcp    = null
        }
      }
    }
  }
}

module "ssh_manager" {
  source         = "../../cluster-provision/ssh-manager"
  status_trigger = module.hypervisor_kvm.vm_status_trigger

  nodes          = local.nodes_list_for_ssh
  credentials_vm = local.credentials_vm_for_ssh
  config_name = {
    cluster_name = var.topology_cluster.cluster_name
  }
}

module "ansible_runner" {
  source         = "../../cluster-provision/ansible-runner"
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
