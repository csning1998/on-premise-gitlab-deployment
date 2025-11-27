# Registry Server Topology & Configuration

variable "redis_cluster_config" {
  description = "Define the registry server including virtual hardware resources."
  type = object({
    cluster_name = string
    nodes = object({
      redis = list(object({
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
    ha_virtual_ip   = optional(string, "172.16.137.250")
    base_image_path = optional(string, "../../../packer/output/05-base-redis/ubuntu-server-24-05-base-redis.qcow2")
  })

  validation {
    condition     = length(var.redis_cluster_config.nodes.redis) % 2 != 0
    error_message = "The number of master nodes must be an odd number (1, 3, 5, etc.) to ensure a stable Sentinel quorum."
  }

  validation {
    condition     = alltrue([for node in var.redis_cluster_config.nodes.redis : node.vcpu >= 2 && node.ram >= 2048])
    error_message = "Redis nodes require at least 2 vCPUs and 2048MB RAM."
  }

  validation {
    condition     = alltrue([for node in var.redis_cluster_config.nodes.redis : can(cidrnetmask("${node.ip}/32"))])
    error_message = "All provided Redis node IP addresses must be valid IPv4 addresses."
  }
}

# Registry Server Infrastructure Network Configuration

variable "redis_infrastructure" {
  description = "All Libvirt-level infrastructure configurations for the Redis Service."
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
    redis_allowed_subnet = optional(string, "172.16.137.0/24")
    storage_pool_name    = optional(string, "iac-redis")
  })
}
