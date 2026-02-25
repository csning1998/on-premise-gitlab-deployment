
module "build_harbor_postgres_cluster" {
  source = "../../middleware/ha-service-kvm-general"

  # Identity & Service Definitions
  svc_identity = local.svc_postgres_identity
  node_identities = {
    "db"   = local.svc_postgres_identity
    "etcd" = local.svc_etcd_identity
  }

  # Topology (Compute & Storage)
  topology_cluster = local.topology_cluster

  # Network Infrastructure with Dual-Tier
  network_infrastructure_map = local.network_infrastructure_map

  # Security & Credentials
  credentials_system            = local.sec_system_creds
  security_vault_agent_identity = local.sec_vault_agent_identity

  # Generic Ansible Configuration
  ansible_inventory_template_file = var.ansible_files.inventory_template_file
  ansible_template_vars           = local.ansible_template_vars
  ansible_extra_vars              = local.ansible_extra_vars
  ansible_playbook_file           = var.ansible_files.playbook_file
}
