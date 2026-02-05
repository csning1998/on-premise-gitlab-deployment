
module "dev_harbor" {
  source = "../../modules/29-harbor-single"

  topology_config = var.dev_harbor_compute
  infra_config    = var.dev_harbor_infra
  service_domain  = local.service_domain

  vault_role_name   = local.vault_role_name
  vault_ca_cert_b64 = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
  vault_address     = local.vault_address
}
