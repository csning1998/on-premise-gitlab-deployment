
module "hypervisor_kvm" {
  source = "../../cluster-provision/hypervisor-kvm"

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
  source = "../../cluster-provision/ssh-manager"

  config_name = var.topology_config.cluster_identity.cluster_name
  nodes       = [for k, v in local.all_nodes_map : { key = k, ip = v.ip }]

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
  status_trigger = module.hypervisor_kvm.vm_status_trigger
}

module "ansible_runner" {
  source = "../../cluster-provision/ansible-runner"

  ansible_config = {
    root_path       = local.ansible_root_path
    ssh_config_path = module.ssh_manager.ssh_config_file_path
    playbook_file   = "playbooks/10-provision-vault.yaml"
    inventory_file  = "inventory-${var.topology_config.cluster_identity.cluster_name}.yaml"
  }

  inventory_content = templatefile("${path.module}/../../../templates/inventory-vault-cluster.yaml.tftpl", {
    ansible_ssh_user = data.vault_generic_secret.iac_vars.data["vm_username"]
    service_name     = var.topology_config.cluster_identity.service_name

    vault_nodes  = var.topology_config.vault_cluster.nodes
    haproxy_node = var.topology_config.haproxy_config.nodes

    vault_ha_virtual_ip     = var.topology_config.haproxy_config.virtual_ip
    vault_allowed_subnet    = var.infra_config.allowed_subnet
    vault_nat_subnet_prefix = local.nat_network_subnet_prefix
  })

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  extra_vars = {
    "vault_keepalived_auth_pass" = data.vault_generic_secret.infra_vars.data["vault_keepalived_auth_pass"]
    "vault_haproxy_stats_pass"   = data.vault_generic_secret.infra_vars.data["vault_haproxy_stats_pass"]
    "vault_local_tls_source_dir" = var.tls_source_dir
  }

  status_trigger = module.ssh_manager.ssh_access_ready_trigger
}
