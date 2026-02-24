
locals {
  # Node Processing & Grouping
  flat_node_map = merge([
    for comp_name, comp_data in var.topology_cluster.components : {
      for node_suffix, node_data in comp_data.nodes :
      "${var.cluster_name}-${comp_name}-${node_suffix}" => {
        ip         = cidrhost(var.network_parameters[comp_data.network_tier].network.hostonly.cidrv4, node_data.ip_suffix)
        vcpu       = node_data.vcpu
        ram        = node_data.ram
        data_disks = node_data.data_disks

        base_image_path = comp_data.base_image_path
        role            = comp_data.role
        network_tier    = comp_data.network_tier
      }
    }
  ]...)

  nodes_by_role = {
    for role in distinct(values(local.flat_node_map).*.role) : role => {
      for name, node in local.flat_node_map : name => node
      if node.role == role
    }
  }
}

locals {
  ansible_root_path = abspath("${path.root}/../../../../ansible")

  primary_tier_key = contains(keys(var.network_bindings), "default") ? "default" : keys(var.network_bindings)[0]
  primary_params   = var.network_parameters[local.primary_tier_key]

  nat_network_subnet_prefix = join(".", slice(split(".", local.primary_params.network.nat.gateway), 0, 3))

  ansible_extra_vars = merge(
    {
      ansible_user        = var.credentials_system.username
      minio_root_password = var.credentials_db.minio_root_password
      minio_vrrp_secret   = var.credentials_db.minio_vrrp_secret
      minio_root_user     = var.credentials_db.minio_root_user

      vault_agent_role_id     = var.credentials_vault_agent.role_id
      vault_agent_secret_id   = var.credentials_vault_agent.secret_id
      vault_ca_cert_b64       = var.credentials_vault_agent.ca_cert_b64
      vault_role_name         = var.credentials_vault_agent.role_name
      vault_addr              = var.credentials_vault_agent.vault_address
      vault_agent_common_name = var.credentials_vault_agent.common_name
    },
    var.security_pki_bundle != null ? {
      vault_server_cert = var.security_pki_bundle.server_cert
      vault_server_key  = var.security_pki_bundle.server_key
      vault_ca_cert     = var.security_pki_bundle.ca_cert
    } : {}
  )
}

# Ansible Configuration (Dynamic Inventory)
locals {
  inventory_template = "${path.module}/../../../templates/inventory-minio-cluster.yaml.tftpl"

  ansible = {
    root_path      = abspath("${path.module}/../../../../ansible")
    playbook_file  = "playbooks/20-provision-data-services.yaml"
    inventory_file = "inventory-${var.cluster_name}-minio.yaml"

    inventory_contents = templatefile(local.inventory_template, {
      minio_nodes = {
        for k, v in local.flat_node_map : k => { ip = v.ip }
        if v.role == "minio"
      }

      cluster_identity = {
        name        = var.cluster_name
        domain      = var.service_domain
        common_name = var.credentials_vault_agent.common_name
      }

      cluster_network = {
        minio_vip             = var.service_vip
        api_frontend_port     = var.service_ports["api"].frontend_port
        console_frontend_port = var.service_ports["console"].frontend_port
        vault_vip             = regex("://([^:]+)", var.credentials_vault_agent.vault_address)[0]
        access_scope          = local.primary_params.network_access_scope
        nat_prefix            = join(".", slice(split(".", local.primary_params.network.nat.gateway), 0, 3))
      }
    })
  }
}

locals {
  vm_credentials_for_hypervisor = {
    username            = var.credentials_system.username
    password            = var.credentials_system.password
    ssh_public_key_path = var.credentials_system.ssh_public_key_path
  }

  vm_credentials_for_ssh = {
    username             = var.credentials_system.username
    ssh_private_key_path = var.credentials_system.ssh_private_key_path
  }

  hypervisor_kvm_infrastructure = {
    for tier, binding in var.network_bindings : tier => {
      network = {
        nat = {
          name_network = binding.nat_net_name
          name_bridge  = binding.nat_bridge_name
          mode         = "nat"
          ips = {
            prefix  = tonumber(split("/", var.network_parameters[tier].network.nat.cidrv4)[1])
            address = var.network_parameters[tier].network.nat.gateway
            dhcp    = var.network_parameters[tier].network.nat.dhcp
          }
        }
        hostonly = {
          name_network = binding.hostonly_net_name
          name_bridge  = binding.hostonly_bridge_name
          mode         = "route"
          ips = {
            prefix  = tonumber(split("/", var.network_parameters[tier].network.hostonly.cidrv4)[1])
            address = var.network_parameters[tier].network.hostonly.gateway
            dhcp    = null
          }
        }
      }
      storage_pool_name = var.topology_cluster.storage_pool_name
    }
  }
}
