
locals {
  nodes_list_for_ssh = [
    for key, node in var.topology_cluster.load_balancer_config.nodes : {
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
    inventory_file     = "inventory-${var.topology_cluster.cluster_name}.yaml"
    inventory_template = local.inventory_template

    inventory_contents = templatefile(local.inventory_template, {
      load_balancer_nodes = local.nodes_map_for_template
      ansible_ssh_user    = var.credentials_vm.username
      service_name        = var.topology_cluster.cluster_name
      service_domain      = var.service_fqdn
      service_segments    = var.network_service_segments
      interface_name      = var.network_service_segments[0].interface_name
      backend_servers     = var.network_service_segments[0].backend_servers
    })
  }
}

locals {
  ansible_extra_vars = merge(
    {
      terraform_runner_subnet = var.network_parameters.network.hostonly.cidrv4
      haproxy_stats_pass      = local.credentials_haproxy_for_ansible.haproxy_stats_pass
      keepalived_auth_pass    = local.credentials_haproxy_for_ansible.keepalived_auth_pass
    },
    # Inject PKI artifacts only if and only if Layer 00 has base64 encoded output.
    var.security_pki_bundle != null ? {
      vault_haproxy_bundle = var.security_pki_bundle.haproxy_bundle
      vault_ca_cert        = var.security_pki_bundle.ca_cert
    } : {}
  )
}

locals {
  credentials_vm_for_hypervisor = {
    username            = var.credentials_vm.username
    password            = var.credentials_vm.password
    ssh_public_key_path = var.credentials_vm.ssh_public_key_path
  }

  credentials_vm_for_ssh = {
    username             = var.credentials_vm.username
    ssh_private_key_path = var.credentials_vm.ssh_private_key_path
  }

  # Secrets for HAProxy and Keepalived
  credentials_haproxy_for_ansible = {
    haproxy_stats_pass   = var.credentials_application.haproxy_stats_pass
    keepalived_auth_pass = var.credentials_application.keepalived_auth_pass
  }
}
