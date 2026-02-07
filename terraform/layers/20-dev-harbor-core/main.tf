
# Call the Identity Module to generate AppRole & Secret ID
resource "vault_approle_auth_backend_role_secret_id" "this" {
  backend   = data.terraform_remote_state.vault_core.outputs.auth_backend_paths["approle"]
  role_name = data.terraform_remote_state.vault_core.outputs.workload_identities_components[local.lookup_key].role_name
}

module "dev_harbor" {
  source = "../../modules/services-docker/harbor"

  topology_config = merge(
    var.dev_harbor_compute,
    {
      cluster_identity = merge(
        var.dev_harbor_compute.cluster_identity,
        {
          cluster_name = local.cluster_name
        }
      )
    }
  )

  infra_config   = var.dev_harbor_infra
  service_domain = local.service_domain

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

  service_credentials = {
    harbor_admin_password = data.vault_generic_secret.db_vars.data["dev_harbor_admin_password"]
    harbor_pg_db_password = data.vault_generic_secret.db_vars.data["dev_harbor_pg_db_password"]
  }

  vault_agent_config = {
    role_id              = data.terraform_remote_state.vault_core.outputs.workload_identities_components[local.lookup_key].role_id
    secret_id            = vault_approle_auth_backend_role_secret_id.this.secret_id
    ca_cert_b64          = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
    role_name            = local.vault_role_name
    vault_server_address = "https://${data.terraform_remote_state.vault_core.outputs.vault_ha_virtual_ip}:443"
  }
}
