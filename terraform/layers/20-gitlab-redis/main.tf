
module "redis_gitlab" {
  source = "../../modules/service-ha/sentinel-cluster"

  topology_config   = var.gitlab_redis_compute
  infra_config      = var.gitlab_redis_infra
  service_domain    = local.service_domain
  vault_role_name   = local.vault_role_name
  vault_ca_cert_b64 = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")

  enable_tls = true
}
