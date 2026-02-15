
# 1. Global Topology and Bootstrap CA.
locals {
  global_topology     = data.terraform_remote_state.topology.outputs
  root_domain         = local.global_topology.domain_suffix
  root_ca_common_name = local.global_topology.pki_settings.root_ca_common_name
  root_ca_pem         = base64decode(data.terraform_remote_state.topology.outputs.vault_pki.ca_cert)
}

resource "local_file" "bootstrap_ca" {
  content  = local.root_ca_pem
  filename = "${path.module}/tls/bootstrap-ca.crt"
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

# 3. Dynamic Service Catalog Mapper
locals {
  # Transform Layer 00 'service_structure' into Layer 20 'service_catalog' format
  service_catalog = {
    for name, data in local.global_topology.service_structure : name => {
      runtime = data.meta.runtime
      stage   = data.meta.stage

      # Map Components: Extract subdomains for SANs
      components = {
        for c_key, c_val in data.meta.components : c_key => {
          subdomains = c_val.subdomains
        }
      }

      # Map Dependencies: Extract runtime for Auth Method decision
      dependencies = {
        for d_key, d_val in data.meta.dependencies : d_key => {
          service_name = d_key # Use the dependency map key as the target service name
          runtime      = d_val.runtime
        }
      }
    }
  }
}

# 4. Generate Vault Roles (Based on Dynamic Catalog)
#    a. Map domains from Global Topology Service Structure
#    b. Inject Metadata (OU)
#    c. Apply TTL Policy
locals {
  # Component Roles (Server Certs): 
  component_roles = {
    for s_name, s_data in local.global_topology.service_structure :
    s_name => {
      for c_key, c_val in s_data.components : "${s_name}-${c_key}" => {
        name            = c_val.role_name
        allowed_domains = c_val.dns_san
        ou              = c_val.ou
        max_ttl         = lookup(local.ttl_policy, s_data.meta.stage, local.ttl_policy["default"]).max
        ttl             = lookup(local.ttl_policy, s_data.meta.stage, local.ttl_policy["default"]).default
      }
    }
  }
  # Dependency Roles (Client Certs / Auth): 
  dependency_roles = {
    for s_name, s_data in local.global_topology.service_structure :
    s_name => {
      for d_key, d_val in s_data.dependencies : "${s_name}-${d_key}-dep" => {
        name            = d_val.role.role_name
        allowed_domains = d_val.role.dns_san
        ou              = d_val.role.ou
        max_ttl         = lookup(local.ttl_policy, s_data.meta.stage, local.ttl_policy["default"]).max
        ttl             = lookup(local.ttl_policy, s_data.meta.stage, local.ttl_policy["default"]).default
      }
    }
  }
}

# 5. Final Flattened Outputs for Module Consumption
locals {
  flat_component_roles  = merge(values(local.component_roles)...)
  flat_dependency_roles = merge(values(local.dependency_roles)...)
}

# 6. Specific Vault Policy for some Workload Identity: 
#    Key must correspond to service_catalog of "${service_name}-${component_name}"
locals {
  workload_identity_extra_policies = {
    "dev-harbor-frontend" = <<EOT
# Allow reading Harbor related App Secrets (KV v2)
path "secret/data/on-premise-gitlab-deployment/dev-harbor/*" {
  capabilities = ["read"]
}
EOT
  }
}
