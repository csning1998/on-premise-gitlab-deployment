
variable "topology_config" {
  description = "Standardized compute topology configuration for MicroK8s HA Cluster."
  type = object({
    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })

    # MicroK8s Nodes (Map)
    nodes = map(object({
      ip   = string
      vcpu = number
      ram  = number
    }))

    ha_config = object({
      virtual_ip = string
      # If not using MetalLB or built-in HA, then the HAProxy node is not mandatory
      haproxy_nodes = optional(map(object({
        ip   = string
        vcpu = number
        ram  = number
      })), {})
    })
    base_image_path = string
    inventory_file  = string
  })

  # MicroK8s Dqlite Quorum
  validation {
    condition     = length(var.topology_config.nodes) % 2 != 0
    error_message = "MicroK8s node count must be an odd number (1, 3, 5, etc.) to ensure a stable Dqlite quorum."
  }

  # Required MicroK8s hardware specification (2vCPU/4GB)
  validation {
    condition = alltrue([
      for k, node in var.topology_config.nodes :
      node.vcpu >= 2 && node.ram >= 4096
    ])
    error_message = "MicroK8s nodes require at least 2 vCPUs and 4096MB RAM to prevent OOM kills."
  }

  # Required MicroK8s VIP format check
  validation {
    condition     = can(cidrnetmask("${var.topology_config.ha_config.virtual_ip}/32"))
    error_message = "The High Availability Virtual IP (VIP) must be a valid IPv4 address."
  }

  # Required MicroK8s node IP format check
  validation {
    condition = alltrue([
      for k, node in var.topology_config.nodes : can(cidrnetmask("${node.ip}/32"))
    ])
    error_message = "All MicroK8s node IPs must be valid IPv4 addresses."
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

  # Required infrastructure network CIDR format check
  validation {
    condition = alltrue([
      can(cidrnetmask(var.infra_config.network.nat.cidrv4)),
      can(cidrnetmask(var.infra_config.network.hostonly.cidrv4)),
      can(cidrnetmask(var.infra_config.allowed_subnet))
    ])
    error_message = "All network CIDRs must be valid."
  }
}
