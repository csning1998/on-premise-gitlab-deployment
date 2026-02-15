
locals {
  nodes_config = var.topology_config.vault_config.nodes

  nodes_list_for_ssh = [
    for key, node in local.nodes_config : {
      key = key
      ip  = node.ip
    }
  ]
  # Gateway IP prefix extraction
  nat_network_subnet_prefix = join(".", slice(split(".", var.network_config.network.nat.gateway), 0, 3))
}

locals {
  nodes_map_for_template = {
    for node in local.nodes_list_for_ssh : node.key => {
      ip = node.ip
    }
  }

  inventory_template = "${path.module}/../../../templates/inventory-vault-cluster.yaml.tftpl"

  ansible = {
    root_path          = abspath("${path.module}/../../../../ansible")
    playbook_file      = "playbooks/10-provision-core-services.yaml"
    inventory_file     = "inventory-${var.topology_config.cluster_name}.yaml"
    inventory_template = local.inventory_template

    inventory_contents = templatefile(local.inventory_template, {
      ansible_ssh_user        = var.vm_credentials.username
      service_identifier      = var.topology_config.cluster_name
      service_domain          = var.service_domain
      vault_nodes             = local.nodes_map_for_template
      vault_nat_subnet_prefix = local.nat_network_subnet_prefix
      vault_ha_virtual_ip     = var.service_vip
      vault_allowed_subnet    = var.network_config.allowed_subnet
    })
  }
}

locals {
  ansible_extra_vars = merge(
    {},
    var.pki_artifacts != null ? {
      vault_server_cert = var.pki_artifacts.server_cert
      vault_server_key  = var.pki_artifacts.server_key
      vault_ca_cert     = var.pki_artifacts.ca_cert
    } : {}
  )
}

locals {
  vm_credentials_for_hypervisor = {
    username            = var.vm_credentials.username
    password            = var.vm_credentials.password
    ssh_public_key_path = var.vm_credentials.ssh_public_key_path
  }

  vm_credentials_for_ssh = {
    username             = var.vm_credentials.username
    ssh_private_key_path = var.vm_credentials.ssh_private_key_path
  }
}
