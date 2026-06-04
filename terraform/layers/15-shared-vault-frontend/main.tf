
module "context" {
  source = "../../modules/layer-context"

  global_topology_identity = data.terraform_remote_state.metadata.outputs.global_topology_identity
  global_topology_network  = data.terraform_remote_state.metadata.outputs.global_topology_network
  global_pki_map           = data.terraform_remote_state.metadata.outputs.global_pki_map
  global_network_baseline  = data.terraform_remote_state.metadata.outputs.global_network_baseline
  global_vault_pki_b64     = data.terraform_remote_state.metadata.outputs.global_vault_pki_b64
  infrastructure_map       = data.terraform_remote_state.network.outputs.infrastructure_map
  guest_vm_data            = data.vault_generic_secret.guest_vm.data

  target_clusters = var.target_clusters
  primary_role    = var.primary_role
  service_config  = var.service_config
}

# Write the Bootstrap CA cert to the tls/ directory.
# This ensures downstream layers (e.g. 20-vault-pki) can reference it
# as ca_cert_file without a circular dependency during provider initialization.
resource "local_file" "bootstrap_ca" {
  content         = base64decode(module.context.global_vault_pki_b64.ca_cert_b64)
  filename        = "${path.root}/tls/bootstrap-ca.crt"
  file_permission = "0644"
}

module "shared_vault" {
  source = "../../middleware/ha-service-kvm-general"

  svc_identity               = module.context.svc_identity
  node_identities            = module.context.node_identities
  topology_cluster           = module.context.topology_cluster
  storage_infrastructure_map = data.terraform_remote_state.volume.outputs.storage_infrastructure_map
  network_infrastructure_map = module.context.network_infrastructure_map
  credentials_system         = module.context.sec_vm_creds

  ansible_generic_config = {
    template_vars = local.ansible_template_vars
    extra_vars    = local.ansible_extra_vars
  }
}
