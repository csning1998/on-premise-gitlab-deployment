
module "hypervisor_kvm" {
  source = "../../../modules/cluster-provision/hypervisor-kvm"

  vm_config = {
    all_nodes_map = {
      for k, v in local.flat_node_map : k => {
        ip              = v.ip
        vcpu            = v.vcpu
        ram             = v.ram
        base_image_path = v.base_image_path
        data_disks      = v.data_disks
        network_tier    = v.network_tier
      }
    }
  }

  create_networks        = false
  credentials            = local.vm_credentials_for_hypervisor
  libvirt_infrastructure = local.hypervisor_kvm_infrastructure
}

module "ssh_manager" {
  source         = "../../../modules/cluster-provision/ssh-manager"
  status_trigger = module.hypervisor_kvm.vm_status_trigger

  nodes = [
    for k, v in local.flat_node_map : {
      key = k
      ip  = v.ip
    }
  ]

  config_name = {
    cluster_name = var.cluster_name
  }

  credentials_vm = local.vm_credentials_for_ssh
}

module "ansible_runner" {
  source         = "../../../modules/cluster-provision/ansible-runner"
  status_trigger = module.ssh_manager.ssh_access_ready_trigger

  credentials_vm = local.vm_credentials_for_ssh

  ansible_config = {
    root_path       = local.ansible.root_path
    ssh_config_path = module.ssh_manager.ssh_config_file_path
    playbook_file   = local.ansible.playbook_file
    inventory_file  = local.ansible.inventory_file
  }

  inventory_content = local.ansible.inventory_contents
  extra_vars        = local.ansible_extra_vars

  # Cleanup old Kubeconfig to ensure fetching the latest
  pre_run_commands = [
    "rm -f ${local.ansible.root_path}/fetched/${split("-", var.cluster_name)[1]}/kubeconfig",
    "mkdir -p ${local.ansible.root_path}/fetched/${split("-", var.cluster_name)[1]}"
  ]
}

# Read Ansible fetched Kubeconfig
data "external" "fetched_kubeconfig" {
  depends_on = [module.ansible_runner]

  program = ["/bin/bash", "-c", <<-EOT
    set -e
    KUBECONFIG_PATH="${local.ansible.root_path}/fetched/${split("-", var.cluster_name)[1]}/kubeconfig"
    if [ ! -f "$KUBECONFIG_PATH" ]; then
      echo '{}'
      exit 0
    fi
    jq -n --arg kc "$(cat $KUBECONFIG_PATH)" '{"content": $kc}'
  EOT
  ]
}
