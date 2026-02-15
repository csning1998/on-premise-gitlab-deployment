
################################################################
#### DO NOT CHANGE BELOW UNLESS YOU KNOW WHAT YOU ARE DOING ####
#### THIS IS THE SINGLE SOURCE OF TRUTH ACROSS ALL SERVICES ####
################################################################

locals {
  network_baseline = var.network_baseline
  service_catalog  = var.service_catalog
}

/**
 * 1. Role Name (Identity) - Define "What it is"
 *      Format: iac-vault-core-role
 * 2. DNS Name (Context) - Define "Where it is"
 *      Format: core.vault.production.iac.local
 * 3. Certificate OU (Context) - Define "Status and Ownership"
 *      Format: ["Env=production", "Runtime=baremetal", "Tag=critical"]
 */

locals {
  /**
   * 1. Dependency Roles and DNS Names
   *    a. role_name: Logic for Role: Parent Service Name + Dependency Component Name
   *                  Format: ${ProjectCode}-${Service}-${Component}-role
   *                  e.g. core-gitlab-postgres-role
   *
   *    b. dns_san:   Logic for DNS Name: Component Name + Service Name + Stage + Domain Suffix
   *                  e.g. postgres.gitlab.production.iac.local
   */
  dependency_roles = flatten([
    for s in var.service_catalog : [
      for d_key, d_data in s.dependencies : {

        key       = "${s.name}-${d_key}-dep"
        role_name = "${s.project_code}-${s.name}-${d_data.component}-dep-role"
        dns_san   = ["${d_data.component}.${s.name}.${s.stage}.${var.domain_suffix}"]

        # Inject Context
        ou = [
          "Provider=${d_data.provider}",
          "Env=${s.stage}",
          "Owner=${s.owner}",
          "Project=${s.project_code}",
          "Runtime=${d_data.runtime}",
          "Tag=${join(",", d_data.tags)}"
        ]

        ttl_stage = s.stage
      }
    ]
  ])

  /**
   * 2. Component Roles and DNS Names
   *    a. role_name: Logic for Role: Parent Service Name + Component Name
   *                  Format: ${ProjectCode}-${Service}-${Component}-role
   *                  e.g. core-gitlab-frontend-role
   *
   *    b. dns_san:   Logic for DNS Name: Subdomain + Service Name + Stage + Domain Suffix
   *                  Determine if the subdomain is the same as the service name
   *                  - Case A: Primary Entrypoint:  
   *                            e.g. gitlab.production.iac.local (Not gitlab.gitlab.production...)
   *                  - Case B: Secondary Entrypoint: 
   *                            e.g. kas.gitlab.production.iac.local
   */
  component_roles = flatten([
    for s in var.service_catalog : [
      for c_key, c_data in s.components : {

        key       = "${s.name}-${c_key}"
        role_name = "${s.project_code}-${s.name}-${c_key}-role"

        dns_san = [
          for sub in c_data.subdomains :
          sub == s.name ?
          "${sub}.${s.stage}.${var.domain_suffix}" :         # Case A
          "${sub}.${s.name}.${s.stage}.${var.domain_suffix}" # Case B
        ]

        ou = [
          "Provider=${s.provider}",
          "Env=${s.stage}",
          "Owner=${s.owner}",
          "Project=${s.project_code}",
          "Runtime=${s.runtime}",
          "Tag=${join(",", s.tags)}"
        ]

        ttl_stage = s.stage
      }
    ]
  ])

  naming_map = merge(
    { for item in local.dependency_roles : item.key => item },
    { for item in local.component_roles : item.key => item }
  )
}
