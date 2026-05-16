
# 1. External State Context
locals {
  state = {
    metadata             = data.terraform_remote_state.metadata.outputs
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
  }
}

# 2. Vault Connection Context (For Provider)
locals {
  vault_address  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_api_port = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
}

# 3. GitLab Identity & Secrets (For Provider)
locals {
  gitlab_fqdn          = local.state.metadata.global_pki_map["gitlab-frontend"].dns_san[0]
  gitlab_root_password = data.vault_kv_secret_v2.gitlab_internal.data["root_password"]
}

# 4. Organizational Structure Mapping (Derived from Keycloak SSoT)
locals {
  # Get groups and users from Layer 40
  kc_groups = data.terraform_remote_state.keycloak_oidc.outputs.keycloak_groups
  kc_users  = data.terraform_remote_state.keycloak_oidc.outputs.oidc_users

  # 4a. Identify Subgroups under 'engineering'
  engineering_groups = {
    for id, meta in local.kc_groups :
    id => {
      name        = upper(id)
      description = meta.description != "" ? meta.description : "Auto-synced team for ${id}"
    }
    if meta.parent == "engineering"
  }

  # 4b. Map Users to Teams based on their Keycloak groups
  dev_team_mapping = {
    for team_id, config in local.engineering_groups :
    team_id => [
      for user_key, user_data in local.kc_users :
      user_key
      if contains(user_data.groups, team_id)
    ]
  }
}

# Assign users to their respective subgroups
locals {
  # Flatten the mapping for easy resource creation
  membership_list = flatten([
    for team, users in local.dev_team_mapping : [
      for user in users : {
        team = team
        user = user
      }
    ]
  ])
}
