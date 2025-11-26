module "provisioner_kvm" {
  source = "../../modules/11-provisioner-kvm-minio"

  # --- Map Layer's specific variables to the Module's generic inputs ---

  # VM Configuration
  vm_config = {
    all_nodes_map   = local.all_nodes_map
    base_image_path = var.minio_cluster_config.base_image_path
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
        name_network = var.minio_infrastructure.network.nat.name_network
        name_bridge  = var.minio_infrastructure.network.nat.name_bridge
        mode         = "nat"
        ips          = var.minio_infrastructure.network.nat.ips
      }
      hostonly = {
        name_network = var.minio_infrastructure.network.hostonly.name_network
        name_bridge  = var.minio_infrastructure.network.hostonly.name_bridge
        mode         = "route"
        ips          = var.minio_infrastructure.network.hostonly.ips
      }
    }
    storage_pool_name = var.minio_infrastructure.storage_pool_name
  }
}

module "ssh_config_manager_minio" {
  source = "../../modules/81-ssh-config-manager"

  config_name = var.minio_cluster_config.cluster_name
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
    ssh_config_path = module.ssh_config_manager_minio.ssh_config_file_path
    playbook_file   = "playbooks/10-provision-minio.yaml"
    inventory_file  = "inventory-minio-cluster.yaml"
  }

  inventory_content = templatefile("${path.root}/../../templates/inventory-minio-cluster.yaml.tftpl", {
    ansible_ssh_user = data.vault_generic_secret.iac_vars.data["vm_username"]
    minio_nodes      = local.minio_nodes_map
    haproxy_nodes    = local.haproxy_nodes_map

    minio_allowed_subnet = var.minio_infrastructure.minio_allowed_subnet

  })

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  extra_vars = {
    "minio_root_password" = data.vault_generic_secret.db_vars.data["minio_root_password"]
    "minio_vrrp_secret"   = data.vault_generic_secret.db_vars.data["minio_vrrp_secret"]
  }

  status_trigger = module.ssh_config_manager_minio.ssh_access_ready_trigger
}
