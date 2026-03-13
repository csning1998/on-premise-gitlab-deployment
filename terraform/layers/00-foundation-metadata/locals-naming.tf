
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

  /**
   * 3. SSoT MECE Flattened Outputs
   *    Extract structural identity arrays directly into a consumable map
   */
  _all_items = flatten([
    for s in var.service_catalog : concat(
      [for k, v in s.components : { svc = s, key = k, data = v }],
      [for k, v in s.dependencies : { svc = s, key = k, data = v }]
    )
  ])

  # 1. Establish intermediate variables, pre-calculate base_id and hash_prefix
  _items_with_meta = [
    for item in local._all_items : {
      original    = item
      base_id     = "${item.svc.project_code}-${item.svc.name}-${item.key}"
      hash_prefix = substr(md5("${item.svc.project_code}-${item.svc.name}-${item.key}"), 0, 8)
    }
  ]

  # 2. Replace existing identities_from_items, directly use pre-calculated values
  identities_from_items = merge([
    for item in local._items_with_meta : {
      "${item.original.svc.name}-${item.original.key}" = {
        cluster_name      = item.base_id
        storage_pool_name = "iac-${item.base_id}-pool"
        bridge_name_host  = "br-${item.hash_prefix}"
        bridge_name_nat   = "br-${item.hash_prefix}-nat"
        node_name_prefix  = "${item.base_id}-node"
        ansible_inventory = "inventory-${item.base_id}.yaml"
        ssh_config        = "ssh_${item.base_id}"

        groups = {
          for group in coalesce(item.original.data.node_groups, []) :
          group => {
            node_name_prefix = "${item.base_id}-${group}-node"
          }
        }
      }
    }
  ]...)

  # 3. Use Single Element List for Services Without Components
  identities_from_services_without_components = {
    for s in var.service_catalog :
    "${s.name}" => merge([
      for hash_prefix in [substr(md5("${s.project_code}-${s.name}"), 0, 8)] : {
        cluster_name      = "${s.project_code}-${s.name}"
        storage_pool_name = "iac-${s.project_code}-${s.name}-pool"
        bridge_name_host  = "br-${hash_prefix}"
        bridge_name_nat   = "br-${hash_prefix}-nat"
        node_name_prefix  = "${s.project_code}-${s.name}-node"
        ansible_inventory = "inventory-${s.project_code}-${s.name}.yaml"
        ssh_config        = "ssh_${s.project_code}-${s.name}"
        groups            = {}
      }
    ]...)
    if length(s.components) == 0 && length(s.dependencies) == 0
  }

  identity_map = merge(
    local.identities_from_items,
    local.identities_from_services_without_components
  )
}
