# Redis Cluster Topology & Configuration

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
    base_image_path = optional(string, "../../../packer/output/05-base-redis/ubuntu-server-24-05-base-redis.qcow2")
    ha_virtual_ip   = optional(string, "172.16.138.250")
    inventory_file  = optional(string, "inventory-redis-harbor.yaml")
    service_name    = optional(string, "harbor")
  })
}

# Redis Cluster Infrastructure Network Configuration

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
    redis_allowed_subnet = optional(string, "172.16.138.0/24")
    storage_pool_name    = optional(string, "iac-redis-harbor")
  })
}
