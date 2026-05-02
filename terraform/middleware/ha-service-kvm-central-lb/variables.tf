
variable "svc_identity" {
  description = "The SSoT identity object for this load balancer cluster."
  type = object({
    service_name      = string
    cluster_name      = string
    node_name_prefix  = string
    ansible_inventory = string
    ssh_config        = string
    domain_suffix     = string
  })
}

variable "topology_cluster" {
  description = "Standardized compute topology configuration for Load Balancer HA Cluster."
  type = object({

    cluster_name      = string
    storage_pool_name = string

    load_balancer_config = object({
      nodes = map(object({
        base_image_path = string
        vcpu            = number
        ram             = number
        ip_suffix       = number
      }))
    })
  })

  # At least one Load Balancer Class node
  validation {
    condition     = length(var.topology_cluster.load_balancer_config.nodes) > 0
    error_message = "High Availability architecture requires at least one Load Balancer Class node."
  }

  # Load Balancer Node specification (vCPU >= 2, RAM >= 512)
  validation {
    condition = alltrue([
      for k, node in var.topology_cluster.load_balancer_config.nodes :
      node.vcpu >= 2 && node.ram >= 512
    ])
    error_message = "Load Balancer nodes require at least 2 vCPUs and 512MB RAM."
  }
}

variable "svc_network_map" {
  description = "Pure MECE mapping of calculated network attributes (from 00-foundation-metadata)."
  type        = any
}

variable "network_service_segments" {
  description = "List of network segments (Infrastructure creation only)."
  type = list(object({
    name           = string
    bridge_name    = string
    interface_name = string
    tags           = optional(list(string))
    cidr           = optional(string)
    vrid           = optional(number)
    vip            = optional(string)
    runtime        = optional(string)
    mtu            = optional(number)
    mss            = optional(number)
    node_ips       = optional(map(string))

    ports = optional(map(object({
      frontend_port            = number
      backend_port             = number
      health_check_type        = optional(string, "tcp")
      health_check_http_path   = optional(string, "/")
      health_check_http_expect = optional(string, "")
      health_check_ssl         = optional(bool, false)
      health_check_port        = optional(number)
      send_proxy_v2            = optional(bool, false)
    })))

    backend_servers = optional(list(object({
      name = string
      ip   = string
    })))
  }))
}

variable "security_pki_bundle_b64" {
  description = "PKI certificates passed from Layer 00 via Layer 05"
  type        = any
  default     = null
}

variable "network_infrastructure_map" {
  description = "Standardized infrastructure network configuration."
  type = map(object({
    nat = object({
      name        = string
      bridge_name = string
      gateway     = string
      prefix      = number
      dhcp = optional(object({
        start = string
        end   = string
      }))
      mtu = number
    })
    hostonly = object({
      name        = string
      bridge_name = string
      gateway     = string
      prefix      = number
      mtu         = number
    })
    access_scope = optional(string)
  }))

  validation {
    condition = alltrue([
      for k, v in var.network_infrastructure_map :
      can(cidrhost("${v.nat.gateway}/${v.nat.prefix}", 0)) &&
      can(cidrhost("${v.hostonly.gateway}/${v.hostonly.prefix}", 0))
    ])
    error_message = "All network CIDRs must be valid."
  }
}

variable "ansible_generic_config" {
  description = "Consolidated Ansible configuration including template and extra variables."
  type = object({
    template_vars = any
    extra_vars    = any
  })
  default = {
    template_vars = {}
    extra_vars    = {}
  }
}

# Credentials Injection
variable "credentials_vm" {
  description = "System level credentials (ssh user, password, keys)"
  sensitive   = true
  type = object({
    username             = string
    password             = string
    ssh_public_key_path  = string
    ssh_private_key_path = string
  })
}

variable "credentials_application" {
  description = "HAProxy credentials (stats user, stats password, keepalived auth password)"
  sensitive   = true
  type = object({
    haproxy_stats_pass   = string
    keepalived_auth_pass = string
  })
}
