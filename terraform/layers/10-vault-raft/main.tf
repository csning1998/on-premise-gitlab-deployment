
module "vault_cluster" {
  source = "../../modules/service-ha/vault-raft-cluster"

  # Topology
  topology_config = merge(
    var.vault_compute,
    {
      cluster_identity = merge(
        var.vault_compute.cluster_identity,
        {
          cluster_name = local.cluster_name
        }
      )
    }
  )
  infra_config = var.vault_infra

  # Network Identity
  network_identity = {
    nat_net_name         = local.nat_net_name
    nat_bridge_name      = local.nat_bridge_name
    hostonly_net_name    = local.hostonly_net_name
    hostonly_bridge_name = local.hostonly_bridge_name
    storage_pool_name    = local.storage_pool_name
  }

  # Credentials Injection
  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  vault_credentials = {
    vault_keepalived_auth_pass = data.vault_generic_secret.infra_vars.data["vault_keepalived_auth_pass"]
    vault_haproxy_stats_pass   = data.vault_generic_secret.infra_vars.data["vault_haproxy_stats_pass"]
  }

  tls_source_dir = module.vault_tls_gen.tls_source_dir
}

module "vault_tls_gen" {
  source     = "../../modules/configuration/vault-tls-gen"
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
