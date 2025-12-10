
module "postgres_gitlab" {
  source = "../../modules/21-postgres-ha"

  topology_config = var.gitlab_postgres_compute
  infra_config    = var.gitlab_postgres_infra

  vault_ca_cert_b64 = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
  vault_role_name   = "gitlab-postgres"
}
