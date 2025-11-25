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
    error_message = "The number of master nodes must be an odd number (1, 3, 5, etc.) to ensure a stable Sentinel quorum."
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
