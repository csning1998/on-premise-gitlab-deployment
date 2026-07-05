
variable "svc_identity" {
  description = "SSoT Extracted Identity containing cluster_name, storage_pool, etc. Used for shared components like Ansible & SSH."
  type = object({
    cluster_name      = string
    storage_pool_name = string
    bridge_name_host  = string
    bridge_name_nat   = string
    node_name_prefix  = string
    ansible_inventory = string
    ssh_config        = string
  })
}

variable "node_identities" {
  description = "A map of component names to their specific SSoT identity block, used to resolve node prefixes generically."
  type = map(object({
    node_name_prefix = string
  }))
}

# This is a temporary attribute as all services will gradually migrate to 'host-passthrough'.
# Once the migration is complete, this field will be removed from the schema.
variable "topology_cluster" {
  description = "Compute topology supporting multi-component architecture."
  type = object({
    storage_pool_name = string

    components = map(object({
      base_image_path = string
      role            = string
      network_tier    = optional(string, "default")

      nodes = map(object({
        ip_suffix            = number
        vcpu                 = number
        ram_size             = number
        os_disk_capacity_gib = optional(number)
        cpu_mode             = optional(string, null)

        attached_volumes = optional(list(object({
          pool   = string
          volume = string
        })), [])
      }))
    }))
  })
}

variable "network_infrastructure_map" {
  description = "Raw network infrastructure map passed directly from Layer 05 outputs."
  type = map(object({
    network = object({
      nat = object({
        name        = string
        bridge_name = string
        gateway     = string
        cidr        = string
        dhcp        = optional(any)
        mtu         = number
      })
      hostonly = object({
        name        = string
        bridge_name = string
        gateway     = string
        cidr        = string
        mtu         = number
      })
    })
    lb_config = optional(any)
  }))

  validation {
    condition = alltrue(flatten([
      for k, v in var.network_infrastructure_map : [
        can(cidrnetmask(v.network.nat.cidr)),
        can(cidrnetmask(v.network.hostonly.cidr))
      ]
    ]))
    error_message = "All network CIDRs must be valid IPv4 CIDR ranges."
  }
}

variable "ansible_generic_config" {
  description = "Consolidated Ansible configuration including template and extra variables."
  type = object({
    template_vars = any
    extra_vars    = any
  })
  default = {
    template_vars = {}
    extra_vars    = {}
  }
}

# System Credentials
variable "credentials_system" {
  description = "System level credentials (ssh user, password, keys)"
  sensitive   = true
  type = object({
    username             = string
    password             = string
    ssh_public_key_path  = string
    ssh_private_key_path = string
  })
}

variable "security_vault_agent_identity" {
  description = "Identity configurations for Vault Agent"
  type = object({
    vault_endpoint = string
    role_id        = string
    secret_id      = string
    role_name      = string
    ca_cert_b64    = string
    common_name    = string
    auth_path      = string
  })
  sensitive = true
  default   = null
}


variable "security_pki_bundle_b64" {
  description = "PKI artifacts passed from vault_pki."
  type        = any
  default     = null
}

variable "storage_infrastructure_map" {
  description = "Pure MECE mapping of calculated storage volume attributes, passed from Layer 05 outputs."
  type        = any
  default     = {}
}

variable "static_routes" {
  description = "Static routes keyed by network_tier. Each entry is the list of routes for nodes in that tier."
  type = map(list(object({
    to     = string
    via    = string
    metric = number
  })))
  default = {}
}
