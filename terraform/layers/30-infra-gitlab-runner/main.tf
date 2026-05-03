
module "infra_gitlab_runner" {
  source = "../../middleware/ha-service-kvm-general"

  # Core Identifier & Topology
  svc_identity               = local.svc_identity
  node_identities            = local.node_identities
  topology_cluster           = local.topology_cluster
  storage_infrastructure_map = local.state.volume.storage_infrastructure_map

  # Network & Infrastructure
  network_infrastructure_map = local.network_infrastructure_map

  # System Credentials
  credentials_system            = local.sec_system_creds
  security_vault_agent_identity = local.sec_vault_agent_identity

  # Generic Ansible Configuration
  ansible_generic_config = {
    template_vars = local.ansible_template_vars
    extra_vars    = local.ansible_extra_vars
  }
}
