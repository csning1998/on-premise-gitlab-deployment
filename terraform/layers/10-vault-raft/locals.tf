
locals {
  # Define the absolute path for TLS directory.
  layer_tls_dir = abspath("${path.root}/tls")

  # Service Identity
  svc_name     = var.vault_compute.cluster_identity.service_name
  comp_name    = var.vault_compute.cluster_identity.component
  layer_number = var.vault_compute.cluster_identity.layer_number
  cluster_name = "${local.layer_number}-${local.svc_name}-${local.comp_name}"

  # Naming Convention
  nat_net_name      = "iac-${local.svc_name}-${local.comp_name}-nat"
  hostonly_net_name = "iac-${local.svc_name}-${local.comp_name}-hostonly"
  storage_pool_name = "iac-${local.svc_name}-${local.comp_name}"

  # Bridges
  svc_abbr             = substr(local.svc_name, 0, 3)
  comp_abbr            = substr(local.comp_name, 0, 3)
  nat_bridge_name      = "${local.svc_abbr}-${local.comp_abbr}-natbr"
  hostonly_bridge_name = "${local.svc_abbr}-${local.comp_abbr}-hostbr"
}
