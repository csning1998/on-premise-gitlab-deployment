
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_creds   = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_creds.username
    password = local._gl_creds.token
  }
}

# 1. Global Topology and Bootstrap CA.
# Note: The bootstrap-ca.crt file is written by Layer 15 (15-shared-vault-frontend).
# Layer 20 references it via the path below for the Vault provider's ca_cert_file.
locals {
  state = {
    metadata             = data.terraform_remote_state.metadata.outputs
    vault_sys            = data.terraform_remote_state.vault_sys.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
  }
}

locals {
  sys_vault_addr      = "https://${local.state.vault_sys.service_vip}:443"
  root_domain         = local.state.metadata.global_domain_suffix
  root_ca_common_name = local.state.metadata.global_pki_settings.root_ca_common_name
  bootstrap_ca_path   = local.state.vault_sys.ca_cert_path
}

# 2. TTL Policy for different environments
locals {
  ttl_policy = {
    "production"  = { max = 60 * 60 * 24 * 365, default = 60 * 60 * 24 * 30 } # Max 1 Year, Default 30 Days
    "staging"     = { max = 60 * 60 * 24 * 30, default = 60 * 60 * 24 * 7 }   # Max 30 Days, Default 7 Days
    "development" = { max = 60 * 60 * 24 * 7, default = 60 * 60 * 24 }        # Max 1 Day,   Default 1 Hour
    "default"     = { max = 60 * 60 * 24, default = 60 * 60 }                 # Fallback
  }
}

# 3. Generate Vault Roles (Based on SSoT global_pki_map)
#    a. Map domains from Global Topology
#    b. Inject Metadata (OU)
#    c. Apply TTL Policy
locals {
  # Consolidated Roles (Based on SSoT global_pki_map + Manual Management Roles)
  all_roles = merge(
    {
      for k, v in local.state.metadata.global_pki_map : k => {
        name            = v.role_name
        allowed_domains = distinct(concat(v.dns_san, [local.root_domain]))
        ou              = v.ou
        auth_path       = v.auth_config.path
        auth_method     = v.auth_config.method
        approle_path    = v.auth_config.approle_path
        max_ttl         = lookup(local.ttl_policy, v.ttl_stage, local.ttl_policy["default"]).max
        ttl             = lookup(local.ttl_policy, v.ttl_stage, local.ttl_policy["default"]).default
      }
    },
    {
      "oidc-admin" = {
        name            = "oidc-admin"
        allowed_domains = [local.root_domain]
        ou              = ["infrastructure"]
        auth_path       = "workload-approle"
        auth_method     = "approle"
        approle_path    = "workload-approle"
        max_ttl         = local.ttl_policy["production"].max
        ttl             = local.ttl_policy["production"].default
      },
      "oidc-auditor" = {
        name            = "oidc-auditor"
        allowed_domains = [local.root_domain]
        ou              = ["compliance"]
        auth_path       = "workload-approle"
        auth_method     = "approle"
        approle_path    = "workload-approle"
        max_ttl         = local.ttl_policy["production"].max
        ttl             = local.ttl_policy["production"].default
      },
      # The allowed_domains will be corrected during subsequent testing; no immediate action is required.
      "oidc-developer" = {
        name            = "oidc-developer"
        allowed_domains = ["*"] # To work with multiple domain
        ou              = ["development"]
        auth_path       = "workload-approle"
        auth_method     = "approle"
        approle_path    = "workload-approle"
        max_ttl         = local.ttl_policy["development"].max
        ttl             = local.ttl_policy["development"].default
      }
    }
  )

  # Identification of roles requiring Kubernetes Auth for main.tf resources
  kubernetes_roles = { for k, v in local.all_roles : k => v if v.auth_method == "kubernetes" }
}

# 6. Specific Vault Policy for some Workload Identity:
#    Key must correspond to service_catalog of "${service_name}-${component_name}"
locals {
  workload_identity_extra_rules = {
    "gitlab-postgres" = {
      "secret/data/on-premise-gitlab-deployment/gitlab/postgres" = { capabilities = ["read"] }
    }
    "gitlab-redis" = {
      "secret/data/on-premise-gitlab-deployment/gitlab/redis" = { capabilities = ["read"] }
    }
    "harbor-postgres" = {
      "secret/data/on-premise-gitlab-deployment/harbor/postgres" = { capabilities = ["read"] }
    }
    "harbor-redis" = {
      "secret/data/on-premise-gitlab-deployment/harbor/redis" = { capabilities = ["read"] }
    }
    "harbor-bootstrapper-frontend" = {
      "secret/data/on-premise-gitlab-deployment/harbor-bootstrapper/*" = { capabilities = ["read"] }
    }
    "harbor-frontend" = {
      "secret/data/on-premise-gitlab-deployment/infrastructure/kubeconfig/harbor" = { capabilities = ["create", "update", "read"] }
    }
    "gitlab-frontend" = {
      "secret/data/on-premise-gitlab-deployment/infrastructure/kubeconfig/gitlab" = { capabilities = ["create", "update", "read"] }
    }
    "gitlab-runner" = {
      "secret/data/on-premise-gitlab-deployment/infrastructure/kubeconfig/gitlab-runner" = { capabilities = ["create", "update", "read"] }
    }
    "observability-frontend" = {
      "secret/data/on-premise-gitlab-deployment/infrastructure/kubeconfig/observability" = { capabilities = ["create", "update", "read"] }
      "secret/data/on-premise-gitlab-deployment/observability/frontend"                  = { capabilities = ["read"] }
      "secret/data/on-premise-gitlab-deployment/observability/app/s3_credentials/*"      = { capabilities = ["read"] }
    }

    # Human/Management Identities
    "oidc-admin" = {
      "secret/metadata/"                              = { capabilities = ["list"] }
      "secret/metadata/on-premise-gitlab-deployment/" = { capabilities = ["list"] }

      "secret/data/on-premise-gitlab-deployment/*"     = { capabilities = ["create", "update", "read", "delete", "list"] }
      "secret/metadata/on-premise-gitlab-deployment/*" = { capabilities = ["list", "read", "delete"] }
      "auth/token/lookup-self"                         = { capabilities = ["read"] }
      "identity/lookup/entity"                         = { capabilities = ["read", "update"] }
    }

    "oidc-auditor" = {
      "secret/metadata/*"                          = { capabilities = ["list", "read"] }
      "secret/data/on-premise-gitlab-deployment/*" = { capabilities = ["read", "list"] }
      "sys/audit"                                  = { capabilities = ["read"] }
      "sys/policies/acl"                           = { capabilities = ["list", "read"] }
    }

    "oidc-developer" = {
      "secret/data/on-premise-gitlab-deployment/applications/*"     = { capabilities = ["create", "update", "read", "delete", "list"] }
      "secret/metadata/on-premise-gitlab-deployment/applications/*" = { capabilities = ["list", "read"] }
    }
  }

  management_identities = toset(["oidc-admin", "oidc-auditor", "oidc-developer"])
}
