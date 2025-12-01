
variable "vault_compute" {
  description = "Compute topology for Vault Core service"
  type = object({

    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })

    # Vault Server Nodes (Map)
    nodes = map(object({
      ip   = string
      vcpu = number
      ram  = number
    }))
    ha_config = object({
      virtual_ip = string

      # Vault uses HAProxy as entry point
      haproxy_nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
    })
    base_image_path = string
    inventory_file  = string
  })

  # Vault Raft Quorum
  validation {
    condition     = length(var.vault_compute.nodes) % 2 != 0
    error_message = "Vault node count must be an odd number (1, 3, 5, etc.) to ensure a stable Raft quorum."
  }

  # Vault HA architecture requires at least one HAProxy node
  validation {
    condition     = length(var.vault_compute.ha_config.haproxy_nodes) > 0
    error_message = "Vault HA architecture requires at least one HAProxy node."
  }

  # VIP format check
  validation {
    condition     = can(cidrnetmask("${var.vault_compute.ha_config.virtual_ip}/32"))
    error_message = "The High Availability Virtual IP (VIP) must be a valid IPv4 address."
  }

  # Vault node hardware specification (vCPU >= 2, RAM >= 2048)
  validation {
    condition = alltrue([
      for k, node in var.vault_compute.nodes :
      node.vcpu >= 2 && node.ram >= 2048
    ])
    error_message = "Vault nodes require at least 2 vCPUs and 2048MB RAM."
  }

  # HAProxy node hardware specification (vCPU >= 1, RAM >= 1024)
  validation {
    condition = alltrue([
      for k, node in var.vault_compute.ha_config.haproxy_nodes :
      node.vcpu >= 1 && node.ram >= 1024
    ])
    error_message = "HAProxy nodes require at least 1 vCPU and 1024MB RAM."
  }
}

variable "vault_infra" {
  description = "Infrastructure config for Vault Core service"
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
      can(cidrnetmask(var.vault_infra.network.nat.cidrv4)),
      can(cidrnetmask(var.vault_infra.network.hostonly.cidrv4)),
      can(cidrnetmask(var.vault_infra.allowed_subnet))
    ])
    error_message = "All network CIDRs must be valid."
  }
}

variable "tls_source_dir" {
  description = "The absolute path of the tls directory that Ansible needs to read the certificates from."
  type        = string
  default     = "../../../terraform/layers/10-vault-core/tls"
}
