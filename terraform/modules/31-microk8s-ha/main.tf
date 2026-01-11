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
    playbook_file   = "playbooks/30-provision-microk8s.yaml"
    inventory_file  = "inventory-${var.topology_config.cluster_identity.cluster_name}.yaml"
  }

  inventory_content = templatefile("${path.module}/../../templates/inventory-microk8s-cluster.yaml.tftpl", {
    ansible_ssh_user = data.vault_generic_secret.iac_vars.data["vm_username"]
    service_name     = var.topology_config.cluster_identity.service_name

    microk8s_nodes = local.all_nodes_map

    # Network information
    microk8s_ingress_vip       = var.topology_config.ha_config.virtual_ip
    microk8s_allowed_subnet    = var.infra_config.allowed_subnet
    microk8s_nat_subnet_prefix = local.nat_network_subnet_prefix
  })

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  extra_vars = {}

  # Cleanup old Kubeconfig to ensure fetching the latest
  pre_run_commands = [
    "rm -f ${local.ansible_root_path}/fetched/${var.topology_config.cluster_identity.service_name}/kubeconfig",
    "mkdir -p ${local.ansible_root_path}/fetched/${var.topology_config.cluster_identity.service_name}"
  ]

  status_trigger = module.ssh_manager.ssh_access_ready_trigger
}

# Read Ansible fetched Kubeconfig
data "external" "fetched_kubeconfig" {
  depends_on = [module.ansible_runner]

  program = ["/bin/bash", "-c", <<-EOT
    set -e
    KUBECONFIG_PATH="${local.ansible_root_path}/fetched/${var.topology_config.cluster_identity.service_name}/kubeconfig"
    if [ ! -f "$KUBECONFIG_PATH" ]; then
      echo '{}'
      exit 0
    fi
    jq -n --arg kc "$(cat $KUBECONFIG_PATH)" '{"content": $kc}'
  EOT
  ]
}
