
variable "topology_config" {
  description = "Compute topology for Vault Core service"
  type = object({

    cluster_name      = string
    storage_pool_name = string

    vault_config = object({
      nodes = map(object({
        base_image_path = string
        vcpu            = number
        ram             = number
        ip              = string
      }))
    })
  })

  # Vault Raft Quorum
  validation {
    condition     = length(var.topology_config.vault_config.nodes) % 2 != 0
    error_message = "Vault node count must be an odd number (1, 3, 5, etc.) to ensure a stable Raft quorum."
  }

  # Vault node hardware specification (vCPU >= 1, RAM >= 1024)
  validation {
    condition = alltrue([
      for k, node in var.topology_config.vault_config.nodes :
      node.vcpu >= 1 && node.ram >= 1024
    ])
    error_message = "Vault nodes require at least 1 vCPU and 1024MB RAM."
  }
}

variable "service_vip" {
  type = string
}

variable "service_domain" {
  description = "The FQDN for the Load Balancer service"
  type        = string
}

variable "network_config" {
  description = "Network Config for Hypervisor (Gateways/CIDRs)"
  type = object({
    network = object({
      nat = object({
        gateway = string
        cidrv4  = string
        dhcp    = optional(object({ start = string, end = string }))
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
      can(cidrnetmask(var.network_config.network.nat.cidrv4)),
      can(cidrnetmask(var.network_config.network.hostonly.cidrv4)),
      can(cidrnetmask(var.network_config.allowed_subnet))
    ])
    error_message = "All network CIDRs must be valid."
  }
}

variable "pki_artifacts" {
  description = "PKI certificates passed from Layer 00 via Layer 10"
  type        = any
  default     = null
}

# Network Identity for Naming Policy
variable "network_identity" {
  description = "Pre-calculated network and bridge names passed from Layer"
  type = object({
    nat_net_name         = string
    nat_bridge_name      = string
    hostonly_net_name    = string
    hostonly_bridge_name = string
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
