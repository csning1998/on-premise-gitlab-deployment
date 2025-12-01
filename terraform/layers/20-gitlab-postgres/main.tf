
module "postgres_gitlab" {
  source = "../../modules/21-postgres-ha"

  topology_config = var.gitlab_postgres_compute
  infra_config    = var.gitlab_postgres_infra

  harbor_postgres_tls = {
    ca_cert_pem     = module.postgres_tls.ca_cert_pem
    server_cert_pem = module.postgres_tls.server_cert_pem
    server_key_pem  = module.postgres_tls.server_key_pem
  }
}

module "postgres_tls" {
  source = "../../modules/22-postgres-tls"

  server_ips = concat(
    [var.gitlab_postgres_compute.ha_config.virtual_ip],
    [for node in var.gitlab_postgres_compute.nodes : node.ip],
    [for node in var.gitlab_postgres_compute.ha_config.haproxy_nodes : node.ip]
  )
}
