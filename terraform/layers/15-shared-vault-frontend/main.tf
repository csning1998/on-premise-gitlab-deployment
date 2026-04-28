
# Write the Bootstrap CA cert to the tls/ directory.
# This ensures downstream layers (e.g. 20-vault-pki) can reference it
# as ca_cert_file without a circular dependency during provider initialization.
resource "local_file" "bootstrap_ca" {
  content         = base64decode(local.pki_global_ca.ca_cert)
  filename        = "${path.root}/tls/bootstrap-ca.crt"
  file_permission = "0644"
}

module "vault_cluster" {
  source = "../../middleware/ha-service-kvm-general"

  # Identity & Service Definitions
  svc_identity = local.svc_identity

  node_identities = local.node_identities

  # Topology (Compute & Storage)
  topology_cluster           = local.topology_cluster
  storage_infrastructure_map = local.state.volume.storage_infrastructure_map

  # Network Infrastructure (L2/L3)
  network_infrastructure_map = local.network_infrastructure_map

  # Security & Credentials
  credentials_system = local.sec_vm_creds

  # Ansible Configuration
  ansible_generic_config = {
    template_vars = local.ansible_template_vars
    extra_vars    = local.ansible_extra_vars
  }
}
