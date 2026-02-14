
module "hypervisor_kvm" {
  source = "../../cluster-provision/hypervisor-kvm"

  # VM Configuration
  vm_config = {
    all_nodes_map = local.nodes_config
  }

  # VM Credentials from Vault
  credentials = local.vm_credentials_for_hypervisor

  # Libvirt Network & Storage Configuration
  libvirt_infrastructure = {
    network = {
      nat = {
        name_network = var.network_identity.nat_net_name
        name_bridge  = var.network_identity.nat_bridge_name
        mode         = "nat"
        ips = {
          prefix  = tonumber(split("/", var.network_config.network.nat.cidrv4)[1])
          address = var.network_config.network.nat.gateway
          dhcp    = var.network_config.network.nat.dhcp
        }
      }
      hostonly = {
        name_network = var.network_identity.hostonly_net_name
        name_bridge  = var.network_identity.hostonly_bridge_name
        mode         = "bridge"
        ips = {
          prefix  = tonumber(split("/", var.network_config.network.hostonly.cidrv4)[1])
          address = var.network_config.network.hostonly.gateway
          dhcp    = null
        }
      }
    }
    storage_pool_name = var.topology_config.storage_pool_name
  }
}

module "ssh_manager" {
  source         = "../../cluster-provision/ssh-manager"
  status_trigger = module.hypervisor_kvm.vm_status_trigger

  nodes          = local.nodes_list_for_ssh
  vm_credentials = local.vm_credentials_for_ssh
  config_name    = var.topology_config.cluster_name
}

module "ansible_runner" {
  source         = "../../cluster-provision/ansible-runner"
  status_trigger = module.ssh_manager.ssh_access_ready_trigger

  inventory_content = local.ansible.inventory_contents
  vm_credentials    = local.vm_credentials_for_ssh

  ansible_config = {
    ssh_config_path = module.ssh_manager.ssh_config_file_path
    root_path       = local.ansible.root_path
    playbook_file   = local.ansible.playbook_file
    inventory_file  = local.ansible.inventory_file
  }

  extra_vars = {
    "vault_local_tls_source_dir" = var.tls_source_dir
  }
}
