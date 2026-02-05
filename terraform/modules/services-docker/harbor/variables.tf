
variable "topology_config" {
  description = "Standardized compute topology configuration for Postgres HA Cluster."
  type = object({
    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })

    # Dev Harbor Data Nodes (Map)
    dev_harbor_system_config = object({
      node = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      base_image_path = string
    })
  })

  # Dev Harbor Data Node specification (vCPU >= 2, RAM >= 2048)
  validation {
    condition = alltrue([
      for v in var.topology_config.dev_harbor_system_config.node :
      v.vcpu >= 2 && v.ram >= 2048
    ])
    error_message = "Dev Harbor data nodes require at least 2 vCPUs and 2048MB RAM."
  }
}

variable "infra_config" {
  description = "Standardized infrastructure network configuration."
  type = object({
    network = object({
      nat = object({
        gateway = string
        cidrv4  = string
        dhcp = optional(object({
          start = string
          end   = string
        }))
      })
      hostonly = object({
        gateway = string
        cidrv4  = string
      })
    })
    allowed_subnet = string
  })

  # Network CIDR validation
  validation {
    condition = alltrue([
      can(cidrnetmask(var.infra_config.network.nat.cidrv4)),
      can(cidrnetmask(var.infra_config.network.hostonly.cidrv4)),
      can(cidrnetmask(var.infra_config.allowed_subnet))
    ])
    error_message = "All network CIDRs must be valid."
  }
}

variable "service_domain" {
  description = "The FQDN for the Harbor service"
  type        = string
}

variable "vault_address" {
  description = "The address of the Production Vault"
  type        = string
}

variable "vault_ca_cert_b64" {
  description = "Base64 encoded CA certificate for Vault Agent"
  type        = string
}

variable "vault_role_name" {
  description = "The AppRole name to create in Vault (e.g. gitlab-postgres-role, harbor-postgres-role)"
  type        = string
}

variable "vault_pki_mount_path" {
  description = "The mount path for the PKI backend in Vault"
  type        = string
  default     = "pki/prod"
}
