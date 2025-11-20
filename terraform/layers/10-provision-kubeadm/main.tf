module "provisioner_kvm" {
  source = "../../modules/11-provisioner-kvm"

  # --- Map Layer's specific variables to the Module's generic inputs ---

  # VM Configuration
  vm_config = {
    all_nodes_map   = local.all_nodes_map
    base_image_path = var.kubeadm_cluster_config.base_image_path
  }

  # VM Credentials from Vault
  credentials = {
    username            = data.vault_generic_secret.iac_vars.data["vm_username"]
    password            = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
  }

  # Libvirt Network & Storage Configuration
  libvirt_infrastructure = {
    network = {
      nat = {
        name_network = var.kubeadm_infrastructure.network.nat.name_network
        name_bridge  = var.kubeadm_infrastructure.network.nat.name_bridge
        mode         = "nat"
        ips          = var.kubeadm_infrastructure.network.nat.ips
      }
      hostonly = {
        name_network = var.kubeadm_infrastructure.network.hostonly.name_network
        name_bridge  = var.kubeadm_infrastructure.network.hostonly.name_bridge
        mode         = "route"
        ips          = var.kubeadm_infrastructure.network.hostonly.ips
      }
    }
    storage_pool_name = var.kubeadm_infrastructure.storage_pool_name
  }
}

module "ssh_config_manager_kubeadm" {
  source = "../../modules/81-ssh-config-manager"

  config_name = var.kubeadm_cluster_config.cluster_name
  nodes       = module.provisioner_kvm.all_nodes_map
  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
  status_trigger = module.provisioner_kvm.vm_status_trigger
}

module "bootstrapper_ansible_cluster" {
  source = "../../modules/12-bootstrapper-ansible-kubeadm"

  ansible_config = {
    root_path       = local.ansible_root_path
    registry_host   = var.kubeadm_cluster_config.registry_host
    ssh_config_path = module.ssh_config_manager_kubeadm.ssh_config_file_path
    extra_vars = {
      kubeadm_master_ips    = local.kubeadm_master_ips
      kubeadm_ha_virtual_ip = var.kubeadm_cluster_config.ha_virtual_ip
      kubeadm_pod_subnet    = var.kubeadm_cluster_config.pod_subnet
      k8s_nat_subnet_prefix = local.k8s_cluster_nat_network_subnet_prefix
    }
  }

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  inventory = {
    nodes          = module.provisioner_kvm.all_nodes_map
    status_trigger = module.ssh_config_manager_kubeadm.ssh_access_ready_trigger
  }
}
