module "provisioner_kvm" {
  source = "../81-provisioner-kvm"

  # --- Map Layer's specific variables to the Module's generic inputs ---

  # VM Configuration
  vm_config = {
    all_nodes_map   = local.all_nodes_map
    base_image_path = var.postgres_cluster_config.base_image_path
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
        name_network = var.postgres_infrastructure.network.nat.name_network
        name_bridge  = var.postgres_infrastructure.network.nat.name_bridge
        mode         = "nat"
        ips          = var.postgres_infrastructure.network.nat.ips
      }
      hostonly = {
        name_network = var.postgres_infrastructure.network.hostonly.name_network
        name_bridge  = var.postgres_infrastructure.network.hostonly.name_bridge
        mode         = "route"
        ips          = var.postgres_infrastructure.network.hostonly.ips
      }
    }
    storage_pool_name = var.postgres_infrastructure.storage_pool_name
  }
}

module "ssh_config_manager_postgres" {
  source = "../82-ssh-config-manager"

  config_name = var.postgres_cluster_config.cluster_name
  nodes       = module.provisioner_kvm.all_nodes_map
  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
  status_trigger = module.provisioner_kvm.vm_status_trigger
}

module "bootstrapper_ansible_cluster" {
  source = "../83-bootstrapper-ansible-generic"

  ansible_config = {
    root_path       = local.ansible_root_path
    ssh_config_path = module.ssh_config_manager_postgres.ssh_config_file_path
    playbook_file   = "playbooks/20-provision-data-services.yaml"
    inventory_file  = var.postgres_cluster_config.inventory_file
  }
  inventory_content = templatefile("${path.module}/../../templates/inventory-postgres-cluster.yaml.tftpl", {
    ansible_ssh_user = data.vault_generic_secret.iac_vars.data["vm_username"]
    service_name     = var.postgres_cluster_config.service_name

    postgres_etcd_nodes = local.postgres_etcd_nodes_map
    postgres_nodes      = local.postgres_nodes_map
    haproxy_nodes       = local.haproxy_nodes_map

    etcd_ips     = [for node in values(local.postgres_etcd_nodes_map) : node.ip]
    postgres_ips = [for node in values(local.postgres_nodes_map) : node.ip]

    postgres_ha_virtual_ip     = var.postgres_cluster_config.ha_virtual_ip
    postgres_allowed_subnet    = var.postgres_infrastructure.postgres_allowed_subnet
    postgres_nat_subnet_prefix = local.postgres_nat_network_subnet_prefix
  })

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  extra_vars = {
    "pg_superuser_password"   = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
    "pg_replication_password" = data.vault_generic_secret.db_vars.data["pg_replication_password"]
    "pg_vrrp_secret"          = data.vault_generic_secret.db_vars.data["pg_vrrp_secret"]
  }

  status_trigger = module.ssh_config_manager_postgres.ssh_access_ready_trigger
}
