
# 1. Global Topology and Bootstrap CA.
# Note: The bootstrap-ca.crt file is written by Layer 10 (15-shared-vault).
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
  # Component Roles (Server Certs):
  component_roles = {
    for k, v in local.state.metadata.global_pki_map : k => {
      name            = v.role_name
      allowed_domains = v.dns_san
      ou              = v.ou
      max_ttl         = lookup(local.ttl_policy, v.ttl_stage, local.ttl_policy["default"]).max
      ttl             = lookup(local.ttl_policy, v.ttl_stage, local.ttl_policy["default"]).default
    }
    if !endswith(k, "-dep")
  }

  # Dependency Roles (Client Certs / Auth):
  dependency_roles = {
    for k, v in local.state.metadata.global_pki_map : k => {
      name            = v.role_name
      allowed_domains = v.dns_san
      ou              = v.ou
      max_ttl         = lookup(local.ttl_policy, v.ttl_stage, local.ttl_policy["default"]).max
      ttl             = lookup(local.ttl_policy, v.ttl_stage, local.ttl_policy["default"]).default
    }
    if endswith(k, "-dep")
  }
}

# 6. Specific Vault Policy for some Workload Identity:
#    Key must correspond to service_catalog of "${service_name}-${component_name}"
locals {
  workload_identity_extra_rules = {
    "harbor-bootstrapper-frontend" = {
      "secret/data/on-premise-gitlab-deployment/harbor-bootstrapper/*" = { capabilities = ["read"] }
    }
    "harbor-frontend" = {
      "secret/data/on-premise-gitlab-deployment/infrastructure/kubeconfig/harbor" = { capabilities = ["create", "update", "read"] }
    }
    "gitlab-frontend" = {
      "secret/data/on-premise-gitlab-deployment/infrastructure/kubeconfig/gitlab" = { capabilities = ["create", "update", "read"] }
    }
  }
}
