
module "postgres_harbor" {
  source = "../../modules/21-postgres-ha"

  topology_config = var.harbor_postgres_compute
  infra_config    = var.harbor_postgres_infra

  vault_role_name   = "harbor-postgres"
  vault_ca_cert_b64 = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
}
