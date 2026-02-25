
module "vault_cluster" {
  source = "../../middleware/ha-service-kvm-general"

  # Identity & Service Definitions
  svc_identity = local.svc_identity

  node_identities = local.node_identities

  # Topology (Compute & Storage)
  topology_cluster = local.topology_cluster

  # Network Infrastructure (L2/L3)
  network_infrastructure_map = local.network_infrastructure_map

  # Security & Credentials
  credentials_system = local.sec_system_creds

  # Ansible Configuration
  ansible_inventory_template_file = var.ansible_files.inventory_template_file
  ansible_template_vars           = local.ansible_template_vars
  ansible_extra_vars              = local.ansible_extra_vars
  ansible_playbook_file           = var.ansible_files.playbook_file
}
