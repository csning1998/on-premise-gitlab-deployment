
module "bootstrap_harbor" {
  source = "../../middleware/ha-service-kvm-general"

  # Identity & Service Definitions
  svc_identity = local.svc_identity
  node_identities = {
    (var.bootstrap_harbor_config.role) = local.svc_identity
  }

  # Topology (Compute & Storage) — single node wrapped in HA-compatible structure
  topology_cluster = local.topology_cluster

  # Network Infrastructure
  network_infrastructure_map = local.network_infrastructure_map

  # Security & Credentials
  credentials_system            = local.sec_system_creds
  security_vault_agent_identity = local.sec_vault_agent_identity

  # Ansible Configuration
  ansible_inventory_template_file = var.ansible_files.inventory_template_file
  ansible_playbook_file           = var.ansible_files.playbook_file
  ansible_template_vars           = local.ansible_template_vars
  ansible_extra_vars              = local.ansible_extra_vars
}
