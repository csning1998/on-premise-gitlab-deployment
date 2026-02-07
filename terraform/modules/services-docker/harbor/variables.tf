
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

# Network Identity for Naming Policy
variable "network_identity" {
  description = "Pre-calculated network and bridge names passed from Layer"
  type = object({
    nat_net_name         = string
    nat_bridge_name      = string
    hostonly_net_name    = string
    hostonly_bridge_name = string
    storage_pool_name    = string
  })
}

# Credentials Injection
variable "vm_credentials" {
  description = "System level credentials (ssh user, password, keys)"
  sensitive   = true
  type = object({
    username             = string
    password             = string
    ssh_public_key_path  = string
    ssh_private_key_path = string
  })
}

variable "service_credentials" {
  description = "Service level credentials (patroni, replication)"
  sensitive   = true
  type = object({
    harbor_admin_password = string
    harbor_pg_db_password = string
  })
}

variable "vault_agent_config" {
  description = "Vault Agent Configuration"
  sensitive   = true
  type = object({
    role_id              = string
    secret_id            = string
    ca_cert_b64          = string
    role_name            = string # PKI Role Name
    vault_server_address = string # Vault Server Address
  })
}
