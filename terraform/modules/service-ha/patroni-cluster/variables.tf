
variable "cluster_name" {
  description = "The unique name of the cluster (e.g. gitlab-core)"
  type        = string
}

variable "service_vip" {
  type = string
}

variable "service_domain" {
  description = "The FQDN for the Load Balancer service"
  type        = string
}

variable "security_pki_bundle" {
  description = "PKI certificates passed from Layer 00 via Layer 10"
  type        = any
  default     = null
}

variable "topology_cluster" {
  description = "Standardized compute topology supporting multi-component architecture."
  type = object({
    storage_pool_name = string

    # Key: Component Name (e.g., "node", whatever if it matches `locals.topology_cluster.components.name`.)
    components = map(object({
      base_image_path = string
      role            = string
      network_tier    = optional(string, "default")

      nodes = map(object({
        ip_suffix = number
        vcpu      = number
        ram       = number

        data_disks = optional(list(object({
          name_suffix = string
          capacity    = number
        })), [])
      }))
    }))
  })
}

variable "network_parameters" {
  description = "Map of L3 network configurations keyed by tier name."
  type = map(object({
    network = object({
      nat = object({
        gateway = string,
        cidrv4  = string,
        dhcp    = optional(any)
      })
      hostonly = object({
        gateway = string,
        cidrv4  = string
      })
    })
    network_access_scope = string
  }))

  # Network CIDR validation
  validation {
    condition = alltrue(flatten([
      for k, v in var.network_parameters : [
        can(cidrnetmask(v.network.nat.cidrv4)),
        can(cidrnetmask(v.network.hostonly.cidrv4)),
        can(cidrnetmask(v.network_access_scope))
      ]
    ]))
    error_message = "All network CIDRs must be valid IPv4 CIDR ranges."
  }
}

# Network Identity for Naming Policy
variable "network_bindings" {
  description = "Map of L2 network bindings keyed by tier name."
  type = map(object({
    nat_net_name         = string
    nat_bridge_name      = string
    hostonly_net_name    = string
    hostonly_bridge_name = string
  }))
}

variable "ansible_files" {
  description = "Meta configuration of Ansible inventory for Patroni service."
  type = object({
    playbook_file           = string
    inventory_template_file = string
  })
}


# Credentials Injection
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

variable "credentials_postgres" {
  description = "Database level credentials (patroni, replication)"
  sensitive   = true
  type = object({
    superuser_password   = string
    replication_password = string
    vrrp_secret          = string
  })
}

variable "credentials_vault_agent" {
  description = "Vault Agent Credentials"
  sensitive   = true
  type = object({
    role_id       = string
    secret_id     = string
    ca_cert_b64   = string
    role_name     = string # PKI Role Name
    vault_address = string
    common_name   = string
  })
}

