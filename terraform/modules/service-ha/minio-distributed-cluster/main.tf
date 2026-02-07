
module "hypervisor_kvm" {
  source = "../../cluster-provision/hypervisor-kvm-minio"

  # VM Configuration
  vm_config = {
    all_nodes_map = local.all_nodes_map
  }

  # VM Credentials from Vault
  credentials = {
    username            = var.vm_credentials.username
    password            = var.vm_credentials.password
    ssh_public_key_path = var.vm_credentials.ssh_public_key_path
  }

  # Libvirt Network & Storage Configuration
  libvirt_infrastructure = {
    network = {
      nat = {
        name_network = var.network_identity.nat_net_name
        name_bridge  = var.network_identity.nat_bridge_name
        mode         = "nat"
        ips = {
          address = var.infra_config.network.nat.gateway
          prefix  = tonumber(split("/", var.infra_config.network.nat.cidrv4)[1])
          dhcp    = var.infra_config.network.nat.dhcp
        }
      }
      hostonly = {
        name_network = var.network_identity.hostonly_net_name
        name_bridge  = var.network_identity.hostonly_bridge_name
        mode         = "route"
        ips = {
          address = var.infra_config.network.hostonly.gateway
          prefix  = tonumber(split("/", var.infra_config.network.hostonly.cidrv4)[1])
          dhcp    = null
        }
      }
    }
    storage_pool_name = var.network_identity.storage_pool_name
  }
}

module "ssh_manager" {
  source = "../../cluster-provision/ssh-manager"

  config_name = var.topology_config.cluster_identity.cluster_name
  nodes       = [for k, v in local.all_nodes_map : { key = k, ip = v.ip }]

  vm_credentials = {
    username             = var.vm_credentials.username
    ssh_private_key_path = var.vm_credentials.ssh_private_key_path
  }
  status_trigger = module.hypervisor_kvm.vm_status_trigger
}

module "ansible_runner" {
  source = "../../cluster-provision/ansible-runner"

  ansible_config = {
    root_path       = local.ansible_root_path
    ssh_config_path = module.ssh_manager.ssh_config_file_path
    playbook_file   = "playbooks/20-provision-data-services.yaml"
    inventory_file  = "inventory-${var.topology_config.cluster_identity.cluster_name}.yaml"
  }

  inventory_content = templatefile("${path.module}/../../../templates/inventory-minio-cluster.yaml.tftpl", {
    ansible_ssh_user = var.vm_credentials.username
    service_name     = var.topology_config.cluster_identity.service_name

    haproxy_nodes                 = var.topology_config.haproxy_config.nodes
    haproxy_frontend_port_api     = var.topology_config.haproxy_config.frontend_port_api
    haproxy_frontend_port_console = var.topology_config.haproxy_config.frontend_port_console
    haproxy_backend_port_api      = var.topology_config.haproxy_config.backend_port_api
    haproxy_backend_port_console  = var.topology_config.haproxy_config.backend_port_console

    minio_nodes             = var.topology_config.minio_config.nodes
    minio_ha_virtual_ip     = var.topology_config.haproxy_config.virtual_ip
    minio_tls_node_subnet   = var.infra_config.allowed_subnet
    minio_service_domain    = var.service_domain
    minio_nat_subnet_prefix = local.nat_network_subnet_prefix
  })

  vm_credentials = {
    username             = var.vm_credentials.username
    ssh_private_key_path = var.vm_credentials.ssh_private_key_path
  }

  extra_vars = {
    "minio_root_password" = var.db_credentials.minio_root_password
    "minio_vrrp_secret"   = var.db_credentials.minio_vrrp_secret
    "minio_root_user"     = var.db_credentials.minio_root_user

    "vault_agent_role_id"   = var.vault_agent_config.role_id
    "vault_agent_secret_id" = var.vault_agent_config.secret_id
    "vault_ca_cert_b64"     = var.vault_agent_config.ca_cert_b64
    "vault_role_name"       = var.vault_agent_config.role_name
  }

  status_trigger = module.ssh_manager.ssh_access_ready_trigger
}
