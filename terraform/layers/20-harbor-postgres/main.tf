
module "postgres_harbor" {
  source = "../../modules/21-postgres-ha"

  topology_config = var.harbor_postgres_compute
  infra_config    = var.harbor_postgres_infra

  harbor_postgres_tls = {
    ca_cert_pem     = module.postgres_tls.ca_cert_pem
    server_cert_pem = module.postgres_tls.server_cert_pem
    server_key_pem  = module.postgres_tls.server_key_pem
  }
}

module "postgres_tls" {
  source = "../../modules/22-postgres-tls"

  common_name        = "postgres.iac.local"
  client_common_name = "harbor-client"

  server_ips = concat(
    [for n in var.harbor_postgres_compute.nodes : n.ip], # DB nodes
    [var.harbor_postgres_compute.ha_config.virtual_ip],  # HAProxy VIP
    ["127.0.0.1"]                                        # Localhost
  )
}
