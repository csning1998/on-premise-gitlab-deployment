
module "vault_cluster" {
  source = "../../modules/service-ha/vault-raft-cluster"

  topology_config = var.vault_compute
  infra_config    = var.vault_infra

  tls_source_dir = module.vault_tls_gen.tls_source_dir
}

module "vault_tls_gen" {
  source     = "../../modules/configuration/vault-tls-gen"
  output_dir = local.layer_tls_dir

  tls_mode = var.tls_mode

  vault_cluster = {
    vault_cluster = {
      nodes = {
        for k, v in var.vault_compute.vault_cluster.nodes : k => {
          ip = v.ip
        }
      }
    }
    haproxy_config = {
      virtual_ip = var.vault_compute.haproxy_config.virtual_ip
    }
  }
}

module "vault_pki_setup" {
  source = "../../modules/configuration/vault-pki-setup"

  depends_on = [module.vault_cluster]

  providers = {
    vault = vault.target_cluster
  }

  vault_addr = "https://${var.vault_compute.haproxy_config.virtual_ip}:443"
}
