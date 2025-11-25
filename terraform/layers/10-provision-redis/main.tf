module "provisioner_kvm" {
  source = "../../modules/11-provisioner-kvm"

  # --- Map Layer's specific variables to the Module's generic inputs ---

  # VM Configuration
  vm_config = {
    all_nodes_map   = local.all_nodes_map
    base_image_path = var.redis_cluster_config.base_image_path
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
        name_network = var.redis_infrastructure.network.nat.name_network
        name_bridge  = var.redis_infrastructure.network.nat.name_bridge
        mode         = "nat"
        ips          = var.redis_infrastructure.network.nat.ips
      }
      hostonly = {
        name_network = var.redis_infrastructure.network.hostonly.name_network
        name_bridge  = var.redis_infrastructure.network.hostonly.name_bridge
        mode         = "route"
        ips          = var.redis_infrastructure.network.hostonly.ips
      }
    }
    storage_pool_name = var.redis_infrastructure.storage_pool_name
  }
}

module "ssh_config_manager_redis" {
  source = "../../modules/81-ssh-config-manager"

  config_name = var.redis_cluster_config.cluster_name
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
    ssh_config_path = module.ssh_config_manager_redis.ssh_config_file_path
    playbook_file   = "playbooks/10-provision-redis.yaml"
    inventory_file  = "inventory-redis-cluster.yaml"
  }

  inventory_content = templatefile("${path.root}/../../templates/inventory-redis-cluster.yaml.tftpl", {
    ansible_ssh_user     = data.vault_generic_secret.iac_vars.data["vm_username"]
    redis_nodes          = local.redis_nodes_map
    redis_allowed_subnet = var.redis_infrastructure.redis_allowed_subnet
  })

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  extra_vars = {
    "redis_requirepass" = data.vault_generic_secret.db_vars.data["redis_requirepass"]
    "redis_masterauth"  = data.vault_generic_secret.db_vars.data["redis_masterauth"]
  }

  status_trigger = module.ssh_config_manager_redis.ssh_access_ready_trigger
}
