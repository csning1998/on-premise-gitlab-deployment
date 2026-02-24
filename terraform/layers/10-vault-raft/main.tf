
module "vault_cluster" {
  source = "../../middleware/ha-service-kvm-general"

  # Identity & Service Definitions
  cluster_name = local.svc_cluster_name

  # Topology (Compute & Storage)
  topology_cluster = local.topology_cluster

  # Network Infrastructure (L2/L3)
  network_bindings   = local.network_bindings
  network_parameters = local.network_parameters

  # Security & Credentials
  credentials_system = local.sec_system_creds

  # Ansible Configuration
  ansible_inventory_content = local.ansible_inventory_content
  ansible_extra_vars        = local.ansible_extra_vars
  ansible_playbook_file     = var.ansible_files.playbook_file
}
