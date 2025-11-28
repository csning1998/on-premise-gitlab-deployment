# Registry Server Topology & Configuration

variable "minio_cluster_config" {
  description = "Define the registry server including virtual hardware resources."
  type = object({
    cluster_name = string
    nodes = object({
      minio = list(object({
        ip   = string
        vcpu = number
        ram  = number
        data_disks = list(object({
          name_suffix = string
          capacity    = number
        }))
      }))
      haproxy = list(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
    })
    base_image_path = optional(string, "../../../packer/output/06-base-minio/ubuntu-server-24-06-base-minio.qcow2")
    ha_virtual_ip   = optional(string, "172.16.142.250")
    inventory_file  = optional(string, "inventory-minio-gitlab.yaml")
    service_name    = optional(string, "gitlab")
  })
}

# Registry Server Infrastructure Network Configuration

variable "minio_infrastructure" {
  description = "All Libvirt-level infrastructure configurations for the MinIO Service."
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
    minio_allowed_subnet = optional(string, "172.16.142.0/24")
    storage_pool_name    = optional(string, "iac-gitlab-minio")
  })
}
