module "provisioner_kvm" {

  source = "../81-kvm-vm"

  # VM Configuration
  vm_config = {
    all_nodes_map   = local.all_nodes_map
    base_image_path = var.topology_config.base_image_path
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

  inventory_content = templatefile("${path.module}/../../templates/inventory-postgres-cluster.yaml.tftpl", {
    ansible_ssh_user = data.vault_generic_secret.iac_vars.data["vm_username"]
    service_name     = var.topology_config.cluster_identity.service_name

    postgres_nodes      = var.topology_config.nodes
    postgres_etcd_nodes = var.topology_config.etcd_nodes
    haproxy_nodes       = var.topology_config.ha_config.haproxy_nodes

    haproxy_stats_port = var.topology_config.ha_config.stats_port
    haproxy_rw_port    = var.topology_config.ha_config.rw_proxy
    haproxy_ro_port    = var.topology_config.ha_config.ro_proxy

    etcd_ips     = [for n in var.topology_config.etcd_nodes : n.ip]
    postgres_ips = [for n in var.topology_config.nodes : n.ip]

    postgres_ha_virtual_ip     = var.topology_config.ha_config.virtual_ip
    postgres_mtls_node_subnet  = var.infra_config.allowed_subnet
    postgres_service_domain    = var.service_domain
    postgres_pki_role_name     = var.vault_role_name
    postgres_nat_subnet_prefix = local.nat_network_subnet_prefix
  })

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  extra_vars = {
    # Patroni Database Credentials
    "pg_superuser_password"   = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
    "pg_replication_password" = data.vault_generic_secret.db_vars.data["pg_replication_password"]
    "pg_vrrp_secret"          = data.vault_generic_secret.db_vars.data["pg_vrrp_secret"]

    # Terraform Runner Subnet
    terraform_runner_subnet = var.infra_config.network.hostonly.cidrv4

    # Vault Agent AppRole Credentials
    "vault_agent_role_id"   = vault_approle_auth_backend_role.postgres.role_id
    "vault_agent_secret_id" = vault_approle_auth_backend_role_secret_id.postgres.secret_id
    "vault_ca_cert_b64"     = var.vault_ca_cert_b64
  }

  status_trigger = module.ssh_manager.ssh_access_ready_trigger
}
