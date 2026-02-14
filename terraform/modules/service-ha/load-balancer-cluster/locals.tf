
locals {
  nodes_config = var.topology_config.load_balancer_config.nodes

  nodes_list_for_ssh = [
    for key, node in local.nodes_config : {
      key = key
      ip  = split("/", node.interfaces[1].addresses[0])[0]
    }
  ]
}

locals {
  nodes_map_for_template = {
    for node in local.nodes_list_for_ssh : node.key => {
      ip = node.ip
    }
  }
  inventory_template = "${path.module}/../../../templates/inventory-load-balancer-cluster.yaml.tftpl"

  ansible = {
    root_path          = abspath("${path.module}/../../../../ansible")
    playbook_file      = "playbooks/10-provision-core-services.yaml"
    inventory_file     = "inventory-${var.topology_config.cluster_name}.yaml"
    inventory_template = local.inventory_template

    inventory_contents = templatefile(local.inventory_template, {
      ansible_ssh_user    = var.vm_credentials.username
      service_name        = var.topology_config.cluster_name
      service_domain      = var.service_domain
      service_segments    = var.service_segments
      load_balancer_nodes = local.nodes_map_for_template
      interface_name      = var.service_segments[0].interface_name
      backend_servers     = var.service_segments[0].backend_servers
    })
  }
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

  # Secrets for HAProxy and Keepalived
  haproxy_credentials_for_ansible = {
    haproxy_stats_pass   = var.haproxy_credentials.haproxy_stats_pass
    keepalived_auth_pass = var.haproxy_credentials.keepalived_auth_pass
  }
}
