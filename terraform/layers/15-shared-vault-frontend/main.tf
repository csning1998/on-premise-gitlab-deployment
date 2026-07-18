
module "context" {
  source = "../../modules/layer-context"

  global_topology_identity = data.terraform_remote_state.metadata.outputs.global_topology_identity
  global_topology_network  = data.terraform_remote_state.metadata.outputs.global_topology_network
  global_pki_map           = data.terraform_remote_state.metadata.outputs.global_pki_map
  global_network_baseline  = data.terraform_remote_state.metadata.outputs.global_network_baseline
  infrastructure_map       = data.terraform_remote_state.load_balancer.outputs.infrastructure_map
  guest_vm_data            = data.vault_kv_secret_v2.guest_vm.data

  target_clusters = var.target_clusters
  primary_role    = var.primary_role
  service_config  = var.service_config
}

# Write the Bootstrap CA cert to the tls/ directory.
# This ensures downstream layers (e.g. 20-vault-pki) can reference it
# as ca_cert_file without a circular dependency during provider initialization.
resource "local_file" "bootstrap_ca" {
  content         = local.bootstrap_ca_chain_pem
  filename        = "${path.root}/tls/bootstrap-ca.crt"
  file_permission = "0644"
}

module "shared_vault" {
  source = "../../middleware/ha-service-kvm-general"

  svc_identity               = module.context.svc_identity
  node_identities            = module.context.node_identities
  topology_cluster           = module.context.topology_cluster
  network_infrastructure_map = module.context.network_infrastructure_map
  credentials_system         = module.context.sec_vm_credentials
  static_routes              = module.context.asymmetric_static_routes
  storage_infrastructure_map = data.terraform_remote_state.volume.outputs.storage_infrastructure_map

  ansible_generic_config = {
    template_vars = local.ansible_template_config
    extra_vars    = local.ansible_extra_config
  }
}
