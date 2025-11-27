# Postgres Cluster Topology & Configuration

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
    ha_virtual_ip   = string
    inventory_file  = string # The name of the generated Ansible inventory file.
    service_name    = string # The service identifier (e.g., 'harbor', 'gitlab') used for naming resources.
  })

  # There is no odd number limit for the number of PostgreSQL nodes (e.g. one Primary and multiple Standby nodes)
  validation {
    condition     = length(var.postgres_cluster_config.nodes.etcd) % 2 != 0
    error_message = "The number of etcd nodes must be an odd number (1, 3, 5, etc.) to ensure a stable etcd quorum."
  }

  validation {
    condition     = length(var.postgres_cluster_config.nodes.haproxy) >= 1
    error_message = "At least one HAProxy node is required to route traffic to the Postgres cluster."
  }

  validation {
    condition     = alltrue([for node in var.postgres_cluster_config.nodes.postgres : node.vcpu >= 2 && node.ram >= 4096])
    error_message = "Postgres data nodes require at least 2 vCPUs and 4096MB RAM."
  }

  validation {
    condition     = alltrue([for node in var.postgres_cluster_config.nodes.etcd : node.vcpu >= 2 && node.ram >= 2048])
    error_message = "Etcd nodes require at least 2 vCPUs and 2048MB RAM."
  }

  validation {
    condition     = alltrue([for node in var.postgres_cluster_config.nodes.haproxy : node.vcpu >= 1 && node.ram >= 1024])
    error_message = "HAProxy nodes require at least 1 vCPU and 1024MB RAM."
  }
  validation {
    condition = alltrue(flatten([
      [for node in var.postgres_cluster_config.nodes.postgres : can(cidrnetmask("${node.ip}/32"))],
      [for node in var.postgres_cluster_config.nodes.etcd : can(cidrnetmask("${node.ip}/32"))],
      [for node in var.postgres_cluster_config.nodes.haproxy : can(cidrnetmask("${node.ip}/32"))]
    ]))
    error_message = "All provided Postgres, Etcd, and HAProxy IP addresses must be valid IPv4 addresses."
  }
}

# Postgres Cluster Infrastructure Network Configuration

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
    postgres_allowed_subnet = string
    storage_pool_name       = string
  })
}
