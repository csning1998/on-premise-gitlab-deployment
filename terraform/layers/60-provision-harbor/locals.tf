
# 1. External State Context
locals {
  state = {
    metadata             = data.terraform_remote_state.metadata.outputs
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    keycloak_oidc        = data.terraform_remote_state.keycloak_oidc.outputs
    harbor_bootstrapper  = data.terraform_remote_state.harbor_bootstrapper.outputs
  }
}

# 2. Vault Connection Context (For Provider)
locals {
  vault_address  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_api_port = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
}

# 3. Harbor Identity (For Provider)
locals {
  harbor_hostname = local.state.metadata.global_pki_map["harbor-frontend"].dns_san[0]
}

# 4. OIDC Configuration Context
locals {
  oidc_discovery_url = local.state.keycloak_oidc.issuer_url
  oidc_client_id     = local.state.keycloak_oidc.oidc_clients["harbor_frontend"].client_id
  oidc_client_secret = data.vault_kv_secret_v2.keycloak_harbor_client.data["client_secret"]
}

# 5. Team & Role Group Derivation (from Keycloak SSoT)
locals {
  # Teams that own artifacts (type=team) → get team-{name} project + shared access
  team_groups = {
    for k, v in local.state.keycloak_oidc.keycloak_groups :
    k => v
    if lookup(v.attributes, "type", "") == "team"
  }

  # Cross-team roles (type=role) → elevated access across all team projects
  role_groups = {
    for k, v in local.state.keycloak_oidc.keycloak_groups :
    k => v
    if lookup(v.attributes, "type", "") == "role"
  }
}

# 6. Harbor RBAC Role Mapping
locals {
  harbor_role = {
    project_admin = "projectadmin"
    maintainer    = "maintainer"
    developer     = "developer"
    guest         = "guest"
    limited_guest = "limitedguest"
  }
}
