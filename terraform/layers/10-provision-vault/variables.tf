# HashiCorp Vault Topology & Configuration

variable "vault_cluster_config" {
  description = "Define the Vault server including virtual hardware resources."
  type = object({
    cluster_name = string
    nodes = object({
      vault = list(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      haproxy = list(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
    })
    base_image_path = optional(string, "../../../packer/output/07-base-vault/ubuntu-server-24-07-base-vault.qcow2")
  })

  validation {
    condition     = length(var.vault_cluster_config.nodes.vault) % 2 != 0
    error_message = "The number of Vault nodes must be an odd number (1, 3, 5, etc.) to ensure a stable Raft quorum."
  }

  validation {
    condition     = length(var.vault_cluster_config.nodes.haproxy) > 0
    error_message = "At least one HAProxy node is required for Vault."
  }

  validation {
    condition     = alltrue([for node in var.vault_cluster_config.nodes.vault : node.vcpu >= 2 && node.ram >= 2048])
    error_message = "Vault nodes require at least 2 vCPUs and 2048MB RAM."
  }

  validation {
    condition     = alltrue([for node in var.vault_cluster_config.nodes.haproxy : node.vcpu >= 1 && node.ram >= 1024])
    error_message = "HAProxy nodes require at least 1 vCPU and 1024MB RAM."
  }

  validation {
    condition = alltrue(flatten([
      [for node in var.vault_cluster_config.nodes.vault : can(cidrnetmask("${node.ip}/32"))],
      [for node in var.vault_cluster_config.nodes.haproxy : can(cidrnetmask("${node.ip}/32"))]
    ]))
    error_message = "All provided Vault and HAProxy IP addresses must be valid IPv4 addresses."
  }
}

# Vault Infrastructure Network Configuration

variable "vault_infrastructure" {
  description = "All Libvirt-level infrastructure configurations for the Vault Service."
  type = object({
    network = object({
      nat = object({
        name_network = string
        name_bridge  = string
        ips = object({
          address = string
          prefix  = number
          dhcp = optional(object({
            start = string
            end   = string
          }))
        })
      })
      hostonly = object({
        name_network = string
        name_bridge  = string
        ips = object({
          address = string
          prefix  = number
          dhcp = optional(object({
            start = string
            end   = string
          }))
        })
      })
    })
    vault_allowed_subnet = optional(string, "172.16.139.0/24")
    storage_pool_name    = optional(string, "iac-vault")
  })
}
