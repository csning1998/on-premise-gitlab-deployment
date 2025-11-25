module "provisioner_kvm" {
  source = "../../modules/11-provisioner-kvm"

  # Map Layer's specific variables to the Module's generic inputs

  # VM Configuration
  vm_config = {
    all_nodes_map   = local.all_nodes_map
    base_image_path = var.harbor_cluster_config.base_image_path
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
        name_network = var.harbor_infrastructure.network.nat.name_network
        name_bridge  = var.harbor_infrastructure.network.nat.name_bridge
        mode         = "nat"
        ips          = var.harbor_infrastructure.network.nat.ips
      }
      hostonly = {
        name_network = var.harbor_infrastructure.network.hostonly.name_network
        name_bridge  = var.harbor_infrastructure.network.hostonly.name_bridge
        mode         = "route"
        ips          = var.harbor_infrastructure.network.hostonly.ips
      }
    }
    storage_pool_name = var.harbor_infrastructure.storage_pool_name
  }
}

module "ssh_config_manager_harbor" {
  source = "../../modules/81-ssh-config-manager"

  config_name = var.harbor_cluster_config.cluster_name
  nodes       = module.provisioner_kvm.all_nodes_map
  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
  status_trigger = module.provisioner_kvm.vm_status_trigger
}

module "bootstrapper_ansible_cluster" {
  source = "../../modules/16-bootstrapper-ansible-generic"

  ansible_config = {
    root_path       = local.ansible_root_path
    ssh_config_path = module.ssh_config_manager_harbor.ssh_config_file_path
    playbook_file   = "playbooks/10-provision-harbor.yaml"
    inventory_file  = "inventory-harbor-cluster.yaml"
  }

  inventory_content = templatefile("${path.root}/../../templates/inventory-harbor-cluster.yaml.tftpl", {
    harbor_nodes = [
      for node in module.provisioner_kvm.all_nodes_map : node
      if startswith(node.key, "harbor-node")
    ],
    ansible_ssh_user = data.vault_generic_secret.iac_vars.data["vm_username"]
  })

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  extra_vars = {}

  status_trigger = module.ssh_config_manager_harbor.ssh_access_ready_trigger
}
