
module "service_catalog" {
  source  = var.service_catalog_module_source
  version = var.service_catalog_module_version

  service_catalog  = var.service_catalog
  network_baseline = data.terraform_remote_state.platform_metadata.outputs.global_network_baseline
  domain_suffix    = data.terraform_remote_state.platform_metadata.outputs.global_domain_suffix
}
