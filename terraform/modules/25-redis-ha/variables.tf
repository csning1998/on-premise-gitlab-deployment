variable "topology_config" {
  description = "Standardized compute topology configuration for Redis HA Cluster."
  type = object({
    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })

    # Redis Data Nodes (Map)
    redis_config = object({
      nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      base_image_path = string
    })

    haproxy_config = object({
      virtual_ip = string

      # HAProxy Nodes (Map)
      nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      base_image_path = string
    })
  })

  # Redis Sentinel Quorum
  validation {
    condition     = length(var.topology_config.redis_config.nodes) % 2 != 0
    error_message = "Redis node count must be an odd number (1, 3, 5, etc.) to ensure a stable Sentinel quorum and prevent split-brain scenarios."
  }

  # HAProxy Node Requirement
  validation {
    condition     = length(var.topology_config.haproxy_config.nodes) > 0
    error_message = "High Availability architecture requires at least one HAProxy node to route traffic via VIP."
  }

  # VIP Format Validation
  validation {
    condition     = can(cidrnetmask("${var.topology_config.haproxy_config.virtual_ip}/32"))
    error_message = "The High Availability Virtual IP (VIP) must be a valid IPv4 address."
  }

  # Redis Node Hardware Specification
  validation {
    condition = alltrue([
      for k, node in var.topology_config.redis_config.nodes :
      node.vcpu >= 1 && node.ram >= 1024
    ])
    error_message = "All Redis data nodes must meet minimum requirements: 1 vCPU and 1024MB RAM."
  }

  # HAProxy Node Hardware Specification
  validation {
    condition = alltrue([
      for k, node in var.topology_config.haproxy_config.nodes :
      node.vcpu >= 1 && node.ram >= 512
    ])
    error_message = "All HAProxy nodes must meet minimum requirements: 1 vCPU and 512MB RAM."
  }

  # Redis, HAProxy Node IP Format Validation
  validation {
    condition = alltrue(flatten([
      [for k, node in var.topology_config.redis_config.nodes : can(cidrnetmask("${node.ip}/32"))],
      [for k, node in var.topology_config.haproxy_config.nodes : can(cidrnetmask("${node.ip}/32"))]
    ]))
    error_message = "All provided node IP addresses (Redis and HAProxy) must be valid IPv4 addresses."
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

  # Subnet CIDR Format Validation
  validation {
    condition = alltrue([
      can(cidrnetmask(var.infra_config.network.nat.cidrv4)),
      can(cidrnetmask(var.infra_config.network.hostonly.cidrv4)),
      can(cidrnetmask(var.infra_config.allowed_subnet))
    ])
    error_message = "All network CIDRs (NAT, Hostonly, Allowed Subnet) must be valid CIDR blocks."
  }
}

variable "service_domain" {
  description = "The FQDN for the Redis service"
  type        = string
}

variable "vault_ca_cert_b64" {
  description = "Base64 encoded CA certificate for Vault Agent"
  type        = string
}

variable "vault_role_name" {
  description = "The AppRole name to create in Vault (e.g. gitlab-postgres, harbor-postgres)"
  type        = string
}

variable "enable_tls" {
  description = "Enable TLS/SSL for Redis and Sentinel. Secure by Default."
  type        = bool
  default     = true
}

variable "vault_pki_mount_path" {
  description = "The mount path for the PKI backend in Vault"
  type        = string
  default     = "pki/prod"
}
