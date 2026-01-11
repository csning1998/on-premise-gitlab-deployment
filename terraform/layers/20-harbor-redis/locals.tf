
locals {
  platform_id    = var.harbor_redis_compute.cluster_identity.service_name
  service_domain = local.domain_list[0] # redis.harbor.iac.local

  vault_role_name = data.terraform_remote_state.vault_core.outputs.pki_configuration.redis_roles[local.platform_id]
  domain_list     = data.terraform_remote_state.vault_core.outputs.pki_configuration.redis_domains[local.platform_id]
}
