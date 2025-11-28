module "provisioner_kvm" {
  source = "../81-provisioner-kvm"

  # Map Layer's specific variables to the Module's generic inputs

  # VM Configuration
  vm_config = {
    all_nodes_map   = local.all_nodes_map
    base_image_path = var.microk8s_cluster_config.base_image_path
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
        name_network = var.libvirt_infrastructure.network.nat.name_network
        name_bridge  = var.libvirt_infrastructure.network.nat.name_bridge
        mode         = "nat"
        ips          = var.libvirt_infrastructure.network.nat.ips
      }
      hostonly = {
        name_network = var.libvirt_infrastructure.network.hostonly.name_network
        name_bridge  = var.libvirt_infrastructure.network.hostonly.name_bridge
        mode         = "route"
        ips          = var.libvirt_infrastructure.network.hostonly.ips
      }
    }
    storage_pool_name = var.libvirt_infrastructure.storage_pool_name
  }
}

module "ssh_config_manager_microk8s" {
  source = "../82-ssh-config-manager"

  config_name = var.microk8s_cluster_config.cluster_name
  nodes       = module.provisioner_kvm.all_nodes_map
  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
  status_trigger = module.provisioner_kvm.vm_status_trigger
}

module "bootstrapper_ansible_cluster" {
  source = "../83-bootstrapper-ansible-generic"

  ansible_config = {
    root_path       = local.ansible_root_path
    ssh_config_path = module.ssh_config_manager_microk8s.ssh_config_file_path
    playbook_file   = "playbooks/30-provision-microk8s.yaml"
    inventory_file  = var.microk8s_cluster_config.inventory_file
  }

  inventory_content = templatefile("${path.module}/../../templates/inventory-microk8s-cluster.yaml.tftpl", {
    ansible_ssh_user = data.vault_generic_secret.iac_vars.data["vm_username"]
    service_name     = var.microk8s_cluster_config.service_name

    microk8s_nodes = local.all_nodes_map

    microk8s_ingress_vip       = var.microk8s_cluster_config.ha_virtual_ip
    microk8s_allowed_subnet    = var.libvirt_infrastructure.allowed_subnet
    microk8s_nat_subnet_prefix = local.microk8s_nat_network_subnet_prefix
  })

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  extra_vars = {}

  pre_run_commands = [
    "rm -f ${local.ansible_root_path}/fetched/${var.microk8s_cluster_config.service_name}/kubeconfig",
    "mkdir -p ${local.ansible_root_path}/fetched/${var.microk8s_cluster_config.service_name}"
  ]

  status_trigger = module.ssh_config_manager_microk8s.ssh_access_ready_trigger
}

data "external" "fetched_kubeconfig" {
  depends_on = [module.bootstrapper_ansible_cluster]

  program = ["/bin/bash", "-c", <<-EOT
    set -e
    KUBECONFIG_PATH="${local.ansible_root_path}/fetched/${var.microk8s_cluster_config.service_name}/kubeconfig"
    if [ ! -f "$KUBECONFIG_PATH" ]; then
      echo '{}'
      exit 0
    fi
    jq -n --arg kc "$(cat $KUBECONFIG_PATH)" '{"content": $kc}'
  EOT
  ]
}
