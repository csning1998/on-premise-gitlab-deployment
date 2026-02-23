
module "build_gitlab_postgres_cluster" {
  source = "../../middleware/ha-service-kvm/patroni-cluster"

  # Identity & Service Definitions
  cluster_name   = local.cluster_name
  service_vip    = local.service_vip
  service_domain = local.service_fqdn

  # Topology (Compute & Storage)
  topology_cluster = local.topology_cluster

  # Network Infrastructure with Dual-Tier
  network_bindings   = local.network_bindings
  network_parameters = local.network_parameters

  # Credentials & Security
  credentials_system   = local.credentials_system
  credentials_postgres = local.credentials_postgres

  # Ansible Configuration
  ansible_files = var.ansible_files

  # Layer 00 Artifacts (Root CA) for Ansible trust store
  security_pki_bundle = local.security_pki_bundle

  # Vault Agent Identity Injection
  credentials_vault_agent = merge(
    local.vault_agent_identity,
    {
      secret_id = vault_approle_auth_backend_role_secret_id.patroni_agent.secret_id
    }
  )
}
