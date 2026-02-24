
variable "topology_cluster" {
  description = "Standardized compute topology configuration for Load Balancer HA Cluster."
  type = object({

    cluster_name      = string
    storage_pool_name = string

    load_balancer_config = object({
      nodes = map(object({
        base_image_path = string
        vcpu            = number
        ram             = number
        interfaces = list(object({
          network_name = string
          mac          = string
          alias        = optional(string)
          addresses    = list(string)
        }))
      }))
    })
  })

  # At least one Load Balancer Class node
  validation {
    condition     = length(var.topology_cluster.load_balancer_config.nodes) > 0
    error_message = "High Availability architecture requires at least one Load Balancer Class node."
  }

  # Load Balancer Node specification (vCPU >= 2, RAM >= 1024)
  validation {
    condition = alltrue([
      for k, node in var.topology_cluster.load_balancer_config.nodes :
      node.vcpu >= 2 && node.ram >= 1024
    ])
    error_message = "Load Balancer nodes require at least 2 vCPUs and 1024MB RAM."
  }
}

variable "service_fqdn" {
  description = "The FQDN for the Load Balancer service"
  type        = string
}

variable "network_service_segments" {
  description = "List of network segments (Infrastructure creation only)."
  type = list(object({
    name           = string
    bridge_name    = string
    interface_name = string
    tags           = optional(list(string))
    cidr           = optional(string)
    vrid           = optional(number)
    vip            = optional(string)
    node_ips       = optional(map(string))

    ports = optional(map(object({
      frontend_port            = number
      backend_port             = number
      health_check_type        = optional(string, "tcp")
      health_check_http_path   = optional(string, "/")
      health_check_http_expect = optional(string, "")
      health_check_ssl         = optional(bool, false)
    })))

    backend_servers = optional(list(object({
      name = string
      ip   = string
    })))
  }))
}

variable "security_pki_bundle" {
  description = "PKI certificates passed from Layer 00 via Layer 05"
  type        = any
  default     = null
}

variable "network_parameters" {
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
    access_scope = string
  })

  # Network CIDR validation
  validation {
    condition = alltrue([
      can(cidrnetmask(var.network_parameters.network.nat.cidrv4)),
      can(cidrnetmask(var.network_parameters.network.hostonly.cidrv4)),
      can(cidrnetmask(var.network_parameters.access_scope))
    ])
    error_message = "All network CIDRs must be valid."
  }
}

variable "network_infrastructure" {
  description = "Map of all networks to be passed to KVM module."
  type = map(object({
    hostonly = object({
      name        = string
      bridge_name = string
      gateway     = string
      prefix      = number
    })
    nat = object({
      name        = string
      bridge_name = string
      gateway     = string
      prefix      = number
      dhcp        = optional(any)
    })
  }))
}

# Network Identity for Naming Policy
variable "network_bindings" {
  description = "Pre-calculated network and bridge names passed from Layer"
  type = object({
    nat_net_name         = string
    nat_bridge_name      = string
    hostonly_net_name    = string
    hostonly_bridge_name = string
  })
}

# Credentials Injection
variable "credentials_vm" {
  description = "System level credentials (ssh user, password, keys)"
  sensitive   = true
  type = object({
    username             = string
    password             = string
    ssh_public_key_path  = string
    ssh_private_key_path = string
  })
}

variable "credentials_application" {
  description = "HAProxy credentials (stats user, stats password, keepalived auth password)"
  sensitive   = true
  type = object({
    haproxy_stats_pass   = string
    keepalived_auth_pass = string
  })
}
