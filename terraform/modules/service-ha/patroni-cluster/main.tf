
module "hypervisor_kvm" {

  source = "../../cluster-provision/hypervisor-kvm"

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
        # USE injected names
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

  inventory_content = templatefile("${path.module}/../../../templates/inventory-postgres-cluster.yaml.tftpl", {
    ansible_ssh_user = var.vm_credentials.username
    service_name     = var.topology_config.cluster_identity.service_name

    postgres_nodes      = var.topology_config.postgres_config.nodes
    postgres_etcd_nodes = var.topology_config.etcd_config.nodes
    haproxy_nodes       = var.topology_config.haproxy_config.nodes

    haproxy_stats_port = var.topology_config.haproxy_config.stats_port
    haproxy_rw_port    = var.topology_config.haproxy_config.rw_proxy
    haproxy_ro_port    = var.topology_config.haproxy_config.ro_proxy

    etcd_ips     = [for n in var.topology_config.etcd_config.nodes : n.ip]
    postgres_ips = [for n in var.topology_config.postgres_config.nodes : n.ip]

    postgres_ha_virtual_ip     = var.topology_config.haproxy_config.virtual_ip
    postgres_mtls_node_subnet  = var.infra_config.allowed_subnet
    postgres_service_domain    = var.service_domain
    postgres_nat_subnet_prefix = local.nat_network_subnet_prefix
  })

  vm_credentials = {
    username             = var.vm_credentials.username
    ssh_private_key_path = var.vm_credentials.ssh_private_key_path
  }

  extra_vars = {
    # Patroni Database Credentials
    "pg_superuser_password"   = var.db_credentials.superuser_password
    "pg_replication_password" = var.db_credentials.replication_password
    "pg_vrrp_secret"          = var.db_credentials.vrrp_secret

    # Terraform Runner Subnet
    terraform_runner_subnet = var.infra_config.network.hostonly.cidrv4

    # Vault Agent Config
    "vault_agent_role_id"   = var.vault_agent_config.role_id
    "vault_agent_secret_id" = var.vault_agent_config.secret_id
    "vault_ca_cert_b64"     = var.vault_agent_config.ca_cert_b64
    "vault_role_name"       = var.vault_agent_config.role_name
  }

  status_trigger = module.ssh_manager.ssh_access_ready_trigger
}
