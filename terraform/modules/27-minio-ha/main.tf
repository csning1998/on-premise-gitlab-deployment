module "provisioner_kvm" {
  source = "../81-kvm-vm-minio"

  # VM Configuration
  vm_config = {
    all_nodes_map = local.all_nodes_map
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
        name_network = local.nat_net_name
        name_bridge  = local.nat_bridge_name
        mode         = "nat"
        ips = {
          address = var.infra_config.network.nat.gateway
          prefix  = tonumber(split("/", var.infra_config.network.nat.cidrv4)[1])
          dhcp    = var.infra_config.network.nat.dhcp
        }
      }
      hostonly = {
        name_network = local.hostonly_net_name
        name_bridge  = local.hostonly_bridge_name
        mode         = "route"
        ips = {
          address = var.infra_config.network.hostonly.gateway
          prefix  = tonumber(split("/", var.infra_config.network.hostonly.cidrv4)[1])
          dhcp    = null
        }
      }
    }
    storage_pool_name = local.storage_pool_name
  }
}

module "ssh_manager" {
  source = "../82-ssh-manager"

  config_name = var.topology_config.cluster_identity.cluster_name
  nodes       = [for k, v in local.all_nodes_map : { key = k, ip = v.ip }]

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
  status_trigger = module.provisioner_kvm.vm_status_trigger
}

module "ansible_runner" {
  source = "../83-ansible-runner"

  ansible_config = {
    root_path       = local.ansible_root_path
    ssh_config_path = module.ssh_manager.ssh_config_file_path
    playbook_file   = "playbooks/20-provision-data-services.yaml"
    inventory_file  = "inventory-${var.topology_config.cluster_identity.cluster_name}.yaml"
  }

  inventory_content = templatefile("${path.module}/../../templates/inventory-minio-cluster.yaml.tftpl", {
    ansible_ssh_user = data.vault_generic_secret.iac_vars.data["vm_username"]
    service_name     = var.topology_config.cluster_identity.service_name

    haproxy_nodes = var.topology_config.haproxy_config.nodes
    minio_nodes   = var.topology_config.minio_config.nodes

    minio_ha_virtual_ip     = var.topology_config.haproxy_config.virtual_ip
    minio_root_user         = data.vault_generic_secret.db_vars.data["minio_root_user"]
    minio_tls_node_subnet   = var.infra_config.allowed_subnet
    minio_service_domain    = var.service_domain
    minio_pki_role_name     = var.vault_role_name
    minio_nat_subnet_prefix = local.nat_network_subnet_prefix
  })

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  extra_vars = {
    "minio_root_password" = data.vault_generic_secret.db_vars.data["minio_root_password"]
    "minio_vrrp_secret"   = data.vault_generic_secret.db_vars.data["minio_vrrp_secret"]

    "vault_agent_role_id"   = vault_approle_auth_backend_role.minio.role_id
    "vault_agent_secret_id" = vault_approle_auth_backend_role_secret_id.minio.secret_id
    "vault_ca_cert_b64"     = var.vault_ca_cert_b64
  }

  status_trigger = module.ssh_manager.ssh_access_ready_trigger
}
