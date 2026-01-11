variable "topology_config" {
  description = "Standardized compute topology configuration for MinIO Distributed Cluster."
  type = object({
    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })

    # MinIO Data Nodes (Map) with data_disks
    nodes = map(object({
      ip   = string
      vcpu = number
      ram  = number
      data_disks = list(object({
        name_suffix = string
        capacity    = number
      }))
    }))
    ha_config = object({
      virtual_ip = string

      # HAProxy Nodes (Map) without data_disks
      haproxy_nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
    })
    base_image_path = string
  })

  # MinIO Erasure Coding node count requires single node (Dev) or 4, 8, 12... (Prod)
  validation {
    condition = (
      length(var.topology_config.nodes) == 1 ||
      (length(var.topology_config.nodes) >= 4 && length(var.topology_config.nodes) % 4 == 0)
    )
    error_message = "MinIO cluster size must be exactly 1 node (testing), or a multiple of 4 (4, 8, 16...) for production Erasure Coding."
  }

  # Each MinIO data node must have at least one data disk configured
  validation {
    condition = alltrue([
      for k, node in var.topology_config.nodes : length(node.data_disks) > 0
    ])
    error_message = "Each MinIO data node must have at least one data disk configured."
  }

  # HAProxy node count must be greater than 0
  validation {
    condition     = length(var.topology_config.ha_config.haproxy_nodes) > 0
    error_message = "MinIO HA architecture requires at least one HAProxy node."
  }

  # VIP format check
  validation {
    condition     = can(cidrnetmask("${var.topology_config.ha_config.virtual_ip}/32"))
    error_message = "The High Availability Virtual IP (VIP) must be a valid IPv4 address."
  }

  # Hardware requirements not met. MinIO: 1vCPU/3GB RAM. HAProxy: 1vCPU/2GB RAM.
  validation {
    condition = alltrue(flatten([
      [for k, node in var.topology_config.nodes : node.vcpu >= 1 && node.ram >= 3072],
      [for k, node in var.topology_config.ha_config.haproxy_nodes : node.vcpu >= 1 && node.ram >= 2048]
    ]))
    error_message = "Hardware requirements not met. MinIO: 1vCPU/3GB RAM. HAProxy: 1vCPU/2GB RAM."
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
  description = "The FQDN for the MinIO service"
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

variable "vault_pki_mount_path" {
  description = "The mount path for the PKI backend in Vault"
  type        = string
  default     = "pki/prod"
}
