
module "postgres_harbor" {
  source = "../../modules/service-ha/patroni-cluster"

  topology_config   = var.harbor_postgres_compute
  infra_config      = var.harbor_postgres_infra
  service_domain    = local.service_domain
  vault_role_name   = local.vault_role_name
  vault_ca_cert_b64 = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
}
