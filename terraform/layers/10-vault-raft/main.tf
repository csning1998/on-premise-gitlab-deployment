
module "vault_cluster" {
  source = "../../modules/service-ha/vault-raft-cluster"

  # Topology
  topology_config = {
    cluster_name      = local.cluster_name
    storage_pool_name = local.storage_pool_name

    vault_config = {
      nodes = local.nodes_configuration
    }
  }

  # Inject VIP from SSoT and Network Config / Identity from Layer 05 (Bridge, Gateway, CIDR, DHCP)
  service_vip      = local.service_vip
  service_domain   = local.domain_suffix
  network_config   = local.network_config
  network_identity = local.network_identity
  vm_credentials   = local.vm_credentials

  # Credentials Injection and output directory for TLS
  pki_artifacts = local.vault_pki
}
