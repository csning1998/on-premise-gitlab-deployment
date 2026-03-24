
################################################################
#### DO NOT CHANGE BELOW UNLESS YOU KNOW WHAT YOU ARE DOING ####
#### THIS IS THE SINGLE SOURCE OF TRUTH ACROSS ALL SERVICES ####
################################################################

/**
 * Layer 00: Foundation Metadata - Naming & Identity Topology
 *
 * This file generates the semantic identities for all infrastructure
 * components. It handles:
 * 1. Role Names: Logical names for Vault/Ansible/K8s roles.
 *    Format: {project}-{service}-{component}-role
 * 2. DNS SANs: Subject Alternative Names for TLS certificates.
 *    Supports primary entrypoints (gitlab.prod...) and secondary (kas.gitlab.prod...).
 * 3. Identity Maps: Naming conventions for Libvirt pools, bridges, and nodes.
 */

locals {
  # Mirror variables for local scoping if needed (legacy compatibility)
  network_baseline = var.network_baseline
  service_catalog  = var.service_catalog
}

locals {
  /**
   * 1. Consolidated Service-Component Catalog (SSoT for Naming & Metadata)
   *    This is the "One Place" where all catalog entries are flattened
   *    and assigned deterministic identities.
   */
  _flat_catalog = merge([
    for s_name, s in var.service_catalog : {
      for c_name, c in s.components : "${s_name}-${c_name}" => {
        service_name      = s_name
        comp_name         = c_name
        config            = c
        project           = s.project_code
        stage             = s.stage
        owner             = s.owner
        cluster_name      = "${s.project_code}-${s_name}-${c_name}"
        storage_pool_name = "${s.project_code}-${s_name}-${c_name}-pool"
        hash_prefix       = substr(md5("${s.project_code}-${s_name}-${c_name}"), 0, 8)
      }
    }
  ]...)

  /**
   * 2. Component Roles and DNS Names
   *    Calculates logical roles and certificate metadata.
   */
  component_roles = flatten([
    for key, item in local._flat_catalog : {
      key       = key
      role_name = "${item.cluster_name}-role"

      # DNS SAN Strategy
      # 1. DNS Resolution Validation (RFC 1034/1035):
      #    Supports multi-to-one mapping. Resolver is unidirectional and doesn't conflict with L7 routing.
      # 2. TLS/SSL Handshake Validation (RFC 5280/6066):
      #    Utilizes X.509 SAN extensions and SNI for domain-level isolation and certificate matching.
      
      # Always include a deterministic default SAN for internal certificates.
      # Merge with any Ingress-defined SANs to ensure dns_san[0] is always safe.
      dns_san = distinct(concat(
        flatten([
          for i_key, i_data in coalesce(item.config.ingress, {}) : [
            for sub in i_data.subdomains : 
            join(".", compact([
              sub,
              # Use conditional lookup to avoid ternary operator
              lookup({ (item.service_name) = "" }, sub, item.service_name),
              item.stage,
              var.domain_suffix
            ]))
          ]
        ]),
        ["${item.cluster_name}.${item.stage}.${var.domain_suffix}"]
      ))

      # Organizational Unit (OU) - Encodes metadata into the certificate subject
      ou = [
        "Provider=${item.config.provider}",
        "Env=${item.stage}",
        "Owner=${item.owner}",
        "Project=${item.project}",
        "Runtime=${item.config.runtime}",
        "Tag=${join(",", coalesce(item.config.tags, []))}"
      ]

      ttl_stage = item.stage
    }
  ])

  # Final PKI attribute mapping used by TLS/Vault layers
  pki_map = { for item in local.component_roles : item.key => item }

  /**
   * 3. Semantic Identity Mapping
   *    Generates deterministic names for OS-level and Hypervisor-level objects.
   */

  # Final Identity Map - The SSoT for naming everything in the datacenter
  identity_map = {
    for key, item in local._flat_catalog : key => {
      cluster_name      = item.cluster_name
      storage_pool_name = item.storage_pool_name
      bridge_name_host  = "br-${item.hash_prefix}"
      bridge_name_nat   = "br-${item.hash_prefix}-nat"
      node_name_prefix  = "${item.cluster_name}-node"
      ansible_inventory = "inventory-${item.cluster_name}.yaml"
      ssh_config        = "ssh_${item.cluster_name}"

      # Group-specific naming (e.g. master/worker nodes)
      groups = {
        for group in coalesce(item.config.node_groups, []) :
        group => {
          node_name_prefix = "${item.cluster_name}-${group}-node"
        }
      }
    }
  }
}
