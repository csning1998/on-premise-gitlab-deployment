
# MinIO Compute Topology & Configuration
variable "gitlab_minio_compute" {
  description = "Compute topology for Gitlab MinIO service"
  type = object({
    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })
    nodes = map(object({
      ip   = string
      vcpu = number
      ram  = number
      data_disks = list(object({
        name_suffix = string
        capacity    = number
      }))
    }))
    ha_config = object({
      virtual_ip = string
      haproxy_nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
    })
    base_image_path = string

  })
}

# MinIO Infrastructure Network Configuration
variable "gitlab_minio_infra" {
  description = "Infrastructure config for Gitlab MinIO service"
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
}

variable "gitlab_minio_tenants" {
  description = "Map of buckets and users to create for GitLab"
  type = map(object({
    user_name      = string
    enable_version = bool
    policy_rw      = bool
  }))
}
