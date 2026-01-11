
locals {
  platform_id    = var.gitlab_postgres_compute.cluster_identity.service_name
  service_domain = local.domain_list[0] # pg.gitlab.iac.local

  vault_role_name = data.terraform_remote_state.vault_core.outputs.pki_configuration.postgres_roles[local.platform_id]
  domain_list     = data.terraform_remote_state.vault_core.outputs.pki_configuration.postgres_domains[local.platform_id]
}
