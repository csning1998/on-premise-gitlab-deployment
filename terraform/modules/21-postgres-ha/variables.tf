
variable "topology_config" {
  description = "Standardized compute topology configuration for Postgres HA Cluster."
  type = object({
    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })

    # Postgres Data Nodes (Map)
    nodes = map(object({
      ip   = string
      vcpu = number
      ram  = number
    }))

    # Etcd Nodes (Map)
    etcd_nodes = map(object({
      ip   = string
      vcpu = number
      ram  = number
    }))

    ha_config = object({
      virtual_ip = string
      stats_port = number
      rw_proxy   = number
      ro_proxy   = number

      # HAProxy Nodes (Map)
      haproxy_nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
    })
    base_image_path = string
  })

  # Etcd Raft Quorum
  validation {
    condition     = length(var.topology_config.etcd_nodes) % 2 != 0
    error_message = "Etcd node count must be an odd number (1, 3, 5, etc.) to ensure a stable Raft quorum."
  }

  # At least one HAProxy node
  validation {
    condition     = length(var.topology_config.ha_config.haproxy_nodes) > 0
    error_message = "High Availability architecture requires at least one HAProxy node."
  }

  # VIP format check
  validation {
    condition     = can(cidrnetmask("${var.topology_config.ha_config.virtual_ip}/32"))
    error_message = "The High Availability Virtual IP (VIP) must be a valid IPv4 address."
  }

  # Postgres Data Node specification (vCPU >= 2, RAM >= 4096)
  validation {
    condition = alltrue([
      for k, node in var.topology_config.nodes :
      node.vcpu >= 2 && node.ram >= 4096
    ])
    error_message = "Postgres data nodes require at least 2 vCPUs and 4096MB RAM."
  }

  # Etcd Node specification (vCPU >= 1, RAM >= 3072)
  validation {
    condition = alltrue([
      for k, node in var.topology_config.etcd_nodes :
      node.vcpu >= 1 && node.ram >= 3072
    ])
    error_message = "Etcd nodes require at least 1 vCPU and 3072MB RAM."
  }

  # HAProxy Node Hardware Specification
  validation {
    condition = alltrue([
      for k, node in var.topology_config.ha_config.haproxy_nodes :
      node.vcpu >= 1 && node.ram >= 2048
    ])
    error_message = "All HAProxy nodes must meet minimum requirements: 1 vCPU and 2048MB RAM."
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
  description = "The FQDN for the Postgres service"
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
