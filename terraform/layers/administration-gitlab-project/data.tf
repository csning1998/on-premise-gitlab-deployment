
locals {
  ai_provider = {
    for name, secret in data.vault_generic_secret.registry_platform_ai_provider : name => nonsensitive(secret.data)
  }
  gitlab_subgroup_ids = jsondecode(nonsensitive(data.vault_generic_secret.registry_platform_gitlab_group_subgroups.data["subgroup_ids"]))
}

ephemeral "vault_kv_secret_v2" "state_backend" {
  provider = vault.bastion
  mount    = "secret"
  name     = "${var.gitlab_token_owner_code}/terraform/state-backend"
}

ephemeral "vault_kv_secret_v2" "github_publication" {
  provider = vault.bastion
  mount    = "secret"
  name     = "parent-group-governance/github/publication"
}

ephemeral "vault_kv_secret_v2" "anthropic_console" {
  provider = vault.bastion
  mount    = "secret"
  name     = "parent-group-governance/ai-provider-console/anthropic"
}

# parent-group-governance publishes the subgroup and federation identifiers in the registry, in place of its Terraform state.
data "vault_generic_secret" "registry_platform_gitlab_group_subgroups" {
  provider = vault.bastion
  path     = "registry/platform/gitlab-group/subgroups"
}

data "vault_generic_secret" "registry_platform_ai_provider" {
  for_each = toset(["anthropic", "google-cloud", "azure"])
  provider = vault.bastion
  path     = "registry/platform/ai-provider/${each.key}"
}
