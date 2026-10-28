
terraform {
  required_version = ">= 1.14.0"
  required_providers {
    anthropic = {
      source  = "ippontech/anthropic"
      version = "1.43.5"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.10.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.7.0"
    }
    github = {
      source  = "integrations/github"
      version = "6.13.0"
    }
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "19.2.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "8.4.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }

  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82448331/terraform/state/governance-gitlab-project"
    lock_address   = "https://gitlab.com/api/v4/projects/82448331/terraform/state/governance-gitlab-project/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82448331/terraform/state/governance-gitlab-project/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}

provider "anthropic" {
  # The admin client sends admin_api_key as x-api-key for workspaces and the organization, while the federation and
  # service account endpoints accept the org:admin OAuth token alone.
  admin_api_key = ephemeral.vault_kv_secret_v2.anthropic_console.data["anthropic_admin_api_key"]
  auth_token    = ephemeral.vault_kv_secret_v2.anthropic_console.data["anthropic_oauth_access_token"]
}

provider "azuread" {
  tenant_id = local.state.group_federation_azure.tenant.id
}

provider "azurerm" {
  subscription_id = local.state.group_federation_azure.subscription.id
  tenant_id       = local.state.group_federation_azure.tenant.id
  features {}
}

provider "github" {
  owner = var.github_owner
  token = ephemeral.vault_kv_secret_v2.github_publication.data["deploy_token"]
}

provider "gitlab" {
  token = ephemeral.vault_kv_secret_v2.state_backend.data["token"]
}

provider "vault" {
  alias = "bastion"
}
