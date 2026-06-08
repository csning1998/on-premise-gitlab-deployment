
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_creds   = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_creds.username
    password = local._gl_creds.token
  }
}

# 1. External State Context
locals {
  state = {
    metadata             = data.terraform_remote_state.metadata.outputs
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    keycloak_oidc        = data.terraform_remote_state.keycloak_oidc.outputs
  }
}

# 2. Vault Connection Context (For Provider)
locals {
  vault_address  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_api_port = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
}

# Credential path map alias derived from foundation metadata (L00 SSoT)
locals {
  credential_paths = data.terraform_remote_state.metadata.outputs.global_credential_paths
}

# 3. GitLab Identity & Secrets (For Provider)
locals {
  gitlab_fqdn          = local.state.metadata.global_pki_map["gitlab-frontend"].dns_san[0]
  gitlab_root_password = ephemeral.vault_kv_secret_v2.gitlab_internal.data["root_password"]
}

# 4. Organizational Structure Mapping (Derived from Keycloak SSoT)
locals {
  # Get groups and users from Layer 40
  kc_groups = local.state.keycloak_oidc.groups_metadata
  kc_users  = local.state.keycloak_oidc.oidc_users

  # 4a. Target Organization (Top-Level)
  target_org_name     = local.state.keycloak_oidc.gitlab_sync_root_org
  target_org_metadata = local.state.keycloak_oidc.root_groups_metadata[local.target_org_name]

  # 4b. Subgroups (Teams) under the Target Organization
  target_subgroups = {
    for id, meta in local.kc_groups :
    id => {
      name        = upper(id)
      description = meta.description != "" ? meta.description : "Auto-synced team for ${id}"
    }
    if meta.parent == local.target_org_name
  }

  # 4c. Map Users to Subgroups based on Keycloak memberships
  subgroup_memberships = {
    for team_id, config in local.target_subgroups :
    team_id => [
      for user_key, user_data in local.kc_users :
      user_key
      if contains(user_data.groups, team_id)
    ]
  }

  # 4d. Identify Users who have Admin Privileges based on Keycloak Group Attributes (SSoT)
  admin_users = toset([
    for user_key, user_data in local.kc_users :
    user_key
    if anytrue([
      for g in user_data.groups :
      lookup(local.kc_groups[g].attributes, "gitlab_admin", "false") == "true"
    ])
  ])
}

# Assign users to their respective subgroups
locals {
  # Flatten the mapping for easy resource creation
  membership_list = flatten([
    for team, users in local.subgroup_memberships : [
      for user in users : {
        team = team
        user = user
      }
    ]
  ])
}
