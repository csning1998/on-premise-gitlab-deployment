
locals {
  platform_id    = var.harbor_minio_compute.cluster_identity.service_name
  service_domain = local.domain_list[0] # s3.harbor.iac.local

  vault_role_name = data.terraform_remote_state.vault_core.outputs.pki_configuration.minio_roles[local.platform_id]
  domain_list     = data.terraform_remote_state.vault_core.outputs.pki_configuration.minio_domains[local.platform_id]
}
