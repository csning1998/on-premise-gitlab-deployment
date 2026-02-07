
locals {
  # Root domain for all services.
  root_domain = "iac.local"

  # TTL Policy for different environments
  ttl_policy = {
    "production"  = { max = 60 * 60 * 24 * 365, default = 60 * 60 * 24 * 30 } # Max 1 Year, Default 30 Days
    "staging"     = { max = 60 * 60 * 24 * 30, default = 60 * 60 * 24 * 7 }   # Max 30 Days, Default 7 Days
    "development" = { max = 60 * 60 * 24 * 7, default = 60 * 60 * 24 }        # Max 1 Day,   Default 1 Hour
    "default"     = { max = 60 * 60 * 24, default = 60 * 60 }                 # Fallback
  }

  # Dependency Roles corresponding to Service Catalog dependencies
  dependency_roles = merge([
    for sys_key, sys_config in var.service_catalog : {
      for dep_key, dep_config in sys_config.dependencies : "${sys_key}-${dep_config.service_name}" => {

        # Role Name. e.g. gitlab-postgres-role
        name = "${sys_key}-${dep_config.service_name}-role"

        # Domains. e.g. postgres.gitlab.iac.local AND gitlab.iac.local
        allowed_domains = [
          "${dep_config.service_name}.${sys_key}.${local.root_domain}",
          "${sys_key}.${local.root_domain}"
        ]

        # Metadata Injection: Write into certificate Subject OU. e.g. OU=production, OU=baremetal
        ou = [sys_config.stage, dep_config.runtime]

        max_ttl = lookup(local.ttl_policy, sys_config.stage, local.ttl_policy["default"]).max
        ttl     = lookup(local.ttl_policy, sys_config.stage, local.ttl_policy["default"]).default
      }
    }
  ]...)

  # Component Roles corresponding to Service Catalog components
  component_roles = merge([
    for sys_key, sys_config in var.service_catalog : {
      for comp_key, comp_config in sys_config.components : "${sys_key}-${comp_key}" => {

        # Role Name. e.g. harbor-frontend-role
        name = "${sys_key}-${comp_key}-role"

        # Domains. e.g. harbor.iac.local
        allowed_domains = [for s in comp_config.subdomains : "${s}.${local.root_domain}"]

        # Metadata Injection same as in dependency roles
        ou = [sys_config.stage, sys_config.runtime]

        max_ttl = lookup(local.ttl_policy, sys_config.stage, local.ttl_policy["default"]).max
        ttl     = lookup(local.ttl_policy, sys_config.stage, local.ttl_policy["default"]).default
      }
    }
  ]...)
}
