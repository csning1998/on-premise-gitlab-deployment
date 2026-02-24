
module "vault_cluster" {
  source = "../../middleware/ha-service-kvm/vault-raft-cluster"

  # Identity & Service Definitions
  cluster_name   = local.svc_cluster_name
  service_vip    = local.net_service_vip
  service_domain = local.svc_fqdn

  # Topology (Compute & Storage)
  topology_cluster = local.topology_cluster

  # Network Infrastructure (L2/L3)
  network_bindings   = local.network_bindings
  network_parameters = local.network_parameters

  # Security & Credentials
  credentials_system  = local.sec_system_creds
  security_pki_bundle = local.pki_global_ca

  # Ansible Configuration
  ansible_files = var.ansible_files
}
