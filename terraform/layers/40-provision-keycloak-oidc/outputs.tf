output "issuer_url" {
  value = "${local.keycloak_frontend_url}/realms/${local.realm_id}"
}

output "root_groups_metadata" {
  description = "Metadata for top-level organizational groups."
  value = {
    for k, v in var.keycloak_groups : k => {
      name        = k
      description = v.description
      attributes  = v.attributes
    } if v.parent == null
  }
}

output "groups_metadata" {
  description = "Sanitized metadata for all groups."
  value = {
    for k, v in var.keycloak_groups : k => {
      description = v.description
      parent      = v.parent
      attributes  = v.attributes
    }
  }
}

output "oidc_clients" {
  value     = keycloak_openid_client.clients
  sensitive = true
}

output "vault_redirect_uris" {
  value = local.vault_redirect_uris
}

output "keycloak_groups" {
  value = var.keycloak_groups
}

output "oidc_users" {
  description = "User inventory for downstream layers. Marked as sensitive because it contains initial passwords."
  value = {
    for k, v in var.oidc_users : k => {
      id         = keycloak_user.users[k].id
      username   = v.username
      first_name = v.first_name
      last_name  = v.last_name
      email      = v.email
      groups     = v.groups
      password   = v.password
    }
  }
  sensitive = true
}
