
# Call the Identity Module to generate AppRole & Secret ID
resource "vault_approle_auth_backend_role_secret_id" "this" {
  backend   = data.terraform_remote_state.vault_pki.outputs.auth_backend_paths["approle"]
  role_name = data.terraform_remote_state.vault_pki.outputs.workload_identities_dependencies[local.lookup_key].role_name
}

module "postgres_gitlab" {
  source = "../../modules/service-ha/patroni-cluster"

  # Topology
  topology_config = merge(
    var.gitlab_postgres_compute,
    {
      cluster_identity = merge(
        var.gitlab_postgres_compute.cluster_identity,
        {
          cluster_name = local.cluster_name
        }
      )
    }
  )
  infra_config   = var.gitlab_postgres_infra
  service_domain = local.service_domain

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

  db_credentials = {
    superuser_password   = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
    replication_password = data.vault_generic_secret.db_vars.data["pg_replication_password"]
    vrrp_secret          = data.vault_generic_secret.db_vars.data["pg_vrrp_secret"]
  }

  vault_agent_config = {
    role_id     = data.terraform_remote_state.vault_pki.outputs.workload_identities_dependencies[local.lookup_key].role_id
    secret_id   = vault_approle_auth_backend_role_secret_id.this.secret_id
    ca_cert_b64 = filebase64("${path.root}/../10-vault-raft/tls/vault-ca.crt")
    role_name   = local.vault_role_name
  }
}
