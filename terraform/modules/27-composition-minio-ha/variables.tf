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
    ha_virtual_ip   = string
    inventory_file  = string # The name of the generated Ansible inventory file.
    service_name    = string # The service identifier (e.g., 'harbor', 'gitlab') used for naming resources.
  })

  validation {
    condition     = length(var.minio_cluster_config.nodes.minio) == 1 || (length(var.minio_cluster_config.nodes.minio) >= 4 && length(var.minio_cluster_config.nodes.minio) <= 8 && length(var.minio_cluster_config.nodes.minio) % 4 == 0)
    error_message = "MinIO cluster size must be exactly 1 node, or between 4 and 8 nodes (inclusive) and be a multiple of 4."
  }

  validation {
    condition     = alltrue([for node in var.minio_cluster_config.nodes.minio : length(node.data_disks) > 0])
    error_message = "Each MinIO node must have at least one data disk configured."
  }

  validation {
    condition     = alltrue([for node in var.minio_cluster_config.nodes.minio : node.vcpu >= 2 && node.ram >= 2048])
    error_message = "MinIO nodes require at least 2 vCPUs and 2048MB RAM to ensure stable I/O performance."
  }

  validation {
    condition     = alltrue([for node in var.minio_cluster_config.nodes.minio : can(cidrnetmask("${node.ip}/32"))])
    error_message = "All provided MinIO node IP addresses must be valid IPv4 addresses."
  }

  validation {
    condition     = length(var.minio_cluster_config.nodes.haproxy) > 0
    error_message = "At least one HAProxy node is required for MinIO."
  }
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
    minio_allowed_subnet = string
    storage_pool_name    = string
  })

  validation {
    condition     = can(cidrnetmask(var.minio_infrastructure.minio_allowed_subnet))
    error_message = "MinIO allowed subnet must be a valid CIDR block."
  }
}
