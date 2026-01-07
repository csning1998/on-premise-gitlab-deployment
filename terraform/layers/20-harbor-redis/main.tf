
module "redis_harbor" {
  source = "../../modules/25-redis-ha"

  topology_config = var.harbor_redis_compute
  infra_config    = var.harbor_redis_infra

  vault_ca_cert_b64 = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
  vault_role_name   = "harbor-redis-role"

  // Harbor presently doesnt support Redis Clusters or TLS based connections.
  // Ref: https://goharbor.io/docs/main/install-config/harbor-ha-helm/
  enable_tls = false
}
