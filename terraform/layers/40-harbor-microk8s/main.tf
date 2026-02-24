
module "microk8s_harbor" {
  source = "../../middleware/ha-service-kvm/ha-cluster"

  # Core Identifier & Topology
  cluster_name     = local.svc_cluster_name
  topology_cluster = local.topology_cluster

  # Network & Infrastructure
  network_parameters = local.network_parameters
  network_bindings   = local.network_bindings

  # System Credentials
  credentials_system = local.sec_system_creds

  # Generic Ansible Configuration
  ansible_inventory_content = local.ansible_inventory_content
  ansible_extra_vars        = local.ansible_extra_vars
  ansible_playbook_file     = var.ansible_files.playbook_file
}
