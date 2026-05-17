
locals {
  state = {
    metadata             = data.terraform_remote_state.metadata.outputs
    vault_sys            = data.terraform_remote_state.vault_sys.outputs
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    keycloak             = data.terraform_remote_state.keycloak.outputs
  }
}

locals {
  fdqn = {
    keycloak_frontend   = local.state.metadata.global_pki_map["keycloak-frontend"].dns_san[0]
    vault_frontend      = local.state.metadata.global_pki_map["vault-frontend"].dns_san[0]
    gitlab_frontend     = local.state.metadata.global_pki_map["gitlab-frontend"].dns_san[0]
    gitlab_minio        = local.state.metadata.global_pki_map["gitlab-minio"].dns_san[0]
    harbor_frontend     = local.state.metadata.global_pki_map["harbor-frontend"].dns_san[0]
    harbor_minio        = local.state.metadata.global_pki_map["harbor-minio"].dns_san[0]
    harbor_bootstrapper = local.state.metadata.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  }
}

locals {
  all_groups = distinct(flatten([for u in var.oidc_users : u.groups]))
}

locals {
  # Endpoint Construction
  keycloak_frontend_url   = "https://${local.fdqn.keycloak_frontend}"
  vault_frontend_url      = "https://${local.fdqn.vault_frontend}"
  gitlab_frontend_url     = "https://${local.fdqn.gitlab_frontend}"
  gitlab_minio_url        = "https://${local.fdqn.gitlab_minio}"
  harbor_frontend_url     = "https://${local.fdqn.harbor_frontend}"
  harbor_minio_url        = "https://${local.fdqn.harbor_minio}"
  harbor_bootstrapper_url = "https://${local.fdqn.harbor_bootstrapper}"

  # Admin Credentials
  keycloak_admin_user     = ephemeral.vault_kv_secret_v2.keycloak_admin.data["keycloak_admin_user"]
  keycloak_admin_password = ephemeral.vault_kv_secret_v2.keycloak_admin.data["keycloak_admin_password"]

  # OIDC Configuration Constants
  realm_id = "infra-company"

  # Centralized Redirect URIs for Vault
  vault_redirect_uris = [
    "${local.vault_frontend_url}/ui/vault/auth/oidc/oidc/callback",
    "${local.vault_frontend_url}/ui/vault/auth/oidc/callback",
    "${local.vault_frontend_url}/vault/oidc/callback",
    "http://localhost:8250/oidc/callback"
  ]
}
