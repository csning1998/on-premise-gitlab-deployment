
module "vault_config" {
  source = "../../modules/11-vault-ha"

  topology_config = var.vault_compute
  infra_config    = var.vault_infra

  tls_source_dir = module.vault_tls.tls_source_dir
}

module "vault_tls" {
  source     = "../../modules/12-vault-tls"
  output_dir = local.layer_tls_dir

  tls_mode = var.tls_mode

  vault_cluster = {
    vault_config = {
      nodes = {
        for k, v in var.vault_compute.vault_config.nodes : k => {
          ip = v.ip
        }
      }
    }
    haproxy_config = {
      virtual_ip = var.vault_compute.haproxy_config.virtual_ip
    }
  }
}

module "vault_pki_config" {
  source = "../../modules/13-vault-pki"

  depends_on = [module.vault_config]

  providers = {
    vault = vault.target_cluster
  }

  vault_addr = "https://${var.vault_compute.haproxy_config.virtual_ip}:443"
}
