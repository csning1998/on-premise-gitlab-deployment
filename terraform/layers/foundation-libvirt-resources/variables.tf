
variable "service_catalog" {
  description = "The Single Source of Truth (SSoT) for all services, component, ingress, and dependencies, passed through to the service_catalog module for validation."
  type = map(object({
    owner = string
    stage = string

    components = map(object({
      provider       = string
      runtime        = string
      cidr_index     = number
      os_disk_format = string
      tags           = optional(list(string), [])
      node_groups    = optional(list(string), [])
      ip_range = object({
        start_ip = number
        end_ip   = number
      })
      ports = optional(map(object({
        frontend_port            = number
        backend_port             = number
        health_check_type        = optional(string, "tcp")
        health_check_http_path   = optional(string, "/")
        health_check_http_expect = optional(string, "status 200")
        health_check_ssl         = optional(bool, false)
        health_check_sni         = optional(string)
        health_check_port        = optional(number)
        send_proxy_v2            = optional(bool, false)
      })), {})
      data_disks = optional(list(object({
        name_suffix  = string
        capacity_gib = optional(number, 20)
      })), [])
      ingress = optional(map(object({
        subdomains  = list(string)
        node_groups = optional(list(string), [])
      })), {})
      oidc_client = optional(object({
        name          = string
        redirect_path = string
      }), null)
      ssh = optional(object({
        enabled                  = optional(bool, false)
        username                 = optional(string, "operator")
        identity_algorithm       = optional(string, "ed25519")
        strict_host_key_checking = optional(bool, true)
        password_authentication  = optional(bool, false)
      }), {})
    }))
  }))
}

variable "project_code" {
  description = "Owner code of every catalog entry of this repository. The value prefixes the cluster names, the Vault KV paths, and the identity strings."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.project_code))
    error_message = "project_code must only contain lowercase letters, numbers, and single hyphens between words."
  }
}
