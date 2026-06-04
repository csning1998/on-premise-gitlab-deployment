
variable "svc_identity" {
  description = "Service identity subset providing service_name and domain_suffix for inventory vars."
  type = object({
    service_name  = string
    domain_suffix = string
  })
}

variable "network_service_segments" {
  description = "Full list of service segments with LB metadata (vip, vrid, ports, backend_servers, node_ips)."
  type = list(object({
    name           = string
    vip            = optional(string)
    cidr           = optional(string)
    vrid           = optional(number)
    runtime        = optional(string)
    mtu            = optional(number)
    mss            = optional(number)
    interface_name = string
    tags           = optional(list(string))
    node_ips       = optional(map(string))
    ports = optional(map(object({
      frontend_port            = number
      backend_port             = number
      health_check_type        = optional(string, "tcp")
      health_check_http_path   = optional(string, "/")
      health_check_http_expect = optional(string, "")
      health_check_ssl         = optional(bool, false)
      health_check_sni         = optional(string)
      health_check_port        = optional(number)
      send_proxy_v2            = optional(bool, false)
    })))
    backend_servers = optional(list(object({
      name = string
      ip   = string
    })))
  }))
}

variable "vm_nodes" {
  description = "Computed LB VM nodes map from lb-interface-planner; interfaces[1].addresses[0] provides the HostOnly IP per node."
  type        = any
}

variable "template_vars_base" {
  description = "Additional template variables merged alongside the LB-generated segment vars."
  type        = any
  default     = {}
}
