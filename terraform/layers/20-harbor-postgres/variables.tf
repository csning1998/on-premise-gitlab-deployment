# Registry Server Topology & Configuration

variable "postgres_cluster_config" {
  description = "Define the registry server including virtual hardware resources."
  type = object({
    cluster_name = string
    nodes = object({
      postgres = list(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      etcd = list(object({
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
    base_image_path = optional(string, "../../../packer/output/04-base-postgres/ubuntu-server-24-04-base-postgres.qcow2")
    ha_virtual_ip   = optional(string, "172.16.136.250")
    inventory_file  = optional(string, "inventory-postgres-harbor.yaml")
    service_name    = optional(string, "harbor")
  })
}

# Registry Server Infrastructure Network Configuration

variable "postgres_infrastructure" {
  description = "All Libvirt-level infrastructure configurations for the Postgres Service."
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
    postgres_allowed_subnet = optional(string, "172.16.136.0/24")
    storage_pool_name       = optional(string, "iac-harbor-postgres")
  })
}
