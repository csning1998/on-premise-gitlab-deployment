
module "vault_cluster" {
  source = "../../modules/service-ha/vault-raft-cluster"

  # Identity & Service Definitions
  cluster_name   = local.cluster_name
  service_vip    = local.service_vip
  service_domain = local.service_fqdn

  # Topology (Compute & Storage)
  topology_cluster = local.topology_cluster

  # Network Infrastructure (L2/L3)
  network_bindings   = local.network_bindings
  network_parameters = local.network_parameters

  # Security & Credentials
  credentials_system  = local.credentials_system
  security_pki_bundle = local.security_pki_bundle

  # Ansible Configuration
  ansible_files = var.ansible_files
}
