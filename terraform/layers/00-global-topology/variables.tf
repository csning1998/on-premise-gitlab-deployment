
variable "domain_suffix" {
  description = "Root Domain across all services."
  type        = string
}

variable "pki_settings" {
  description = "Global PKI Identity Settings (SSoT). Defines the legal identity of the infrastructure."
  type = object({
    root_ca_common_name = string
  })
}

variable "pki_force_rotate" {
  description = "Set to true to force regeneration of all certificates (Root CA and Server Certs)."
  type        = bool
  default     = false
}

variable "network_baseline" {
  description = "Base network configuration including CIDR, VIP offsets, and MAC prefixes."
  type = object({
    cidr_block    = string
    vip_offset    = number
    node_ip_start = number
    mac_prefix    = string
  })

  # Validate CIDR Block Format
  validation {
    condition     = can(cidrnetmask(var.network_baseline.cidr_block))
    error_message = "The 'cidr_block' must be a valid IPv4 CIDR range (e.g., 172.16.0.0/16)."
  }

  # Validate MAC Prefix Format. Should be in the format XX:XX:XX (e.g., 52:54:00)
  validation {
    condition     = can(regex("^([0-9a-fA-F]{2}:){2}[0-9a-fA-F]{2}$", var.network_baseline.mac_prefix))
    error_message = "The 'mac_prefix' must be in the format XX:XX:XX (e.g., 52:54:00)."
  }

  # Validate IP Offset Range
  validation {
    condition     = var.network_baseline.vip_offset < 255 && var.network_baseline.node_ip_start < 255
    error_message = "IP offsets must be less than 255 to fit within a /24 subnet."
  }
}

variable "service_catalog" {
  description = "The Single Source of Truth (SSoT) for all services, components, and dependencies."
  type = list(object({
    name         = string # Must be Unique.
    owner        = string
    project_code = string
    provider     = string
    runtime      = string
    stage        = string
    cidr_index   = number
    tags         = optional(list(string), [])

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
    })), {})

    components = map(object({
      subdomains  = list(string)
      node_groups = optional(list(string), [])
    }))

    dependencies = optional(map(object({
      component   = string
      provider    = string
      runtime     = string
      cidr_index  = number
      tags        = optional(list(string), [])
      node_groups = optional(list(string), [])

      ip_range = optional(object({
        start_ip = number
        end_ip   = number
      }))

      ports = optional(map(object({
        frontend_port = number
        backend_port  = number
      })), {})
    })), {})
  }))

  # Validate Service Name Uniqueness
  validation {
    condition     = length(var.service_catalog.*.name) == length(distinct(var.service_catalog.*.name))
    error_message = "Duplicate 'name' detected in service_catalog! Each service must have a unique identity."
  }

  # Validate Runtime Enum for Main Service
  validation {
    condition = alltrue([
      for k, v in var.service_catalog : contains(["kubeadm", "microk8s", "baremetal", "docker", "podman", "minikube"], v.runtime)
    ])
    error_message = "Service runtime must be one of: kubeadm, microk8s, baremetal, docker, podman, minikube."
  }

  # Validate Runtime Enum for Dependency
  validation {
    condition = alltrue(flatten([
      for s_key, s_val in var.service_catalog : [
        for d_key, d_val in s_val.dependencies : contains([
          "baremetal",           # Dedicated VM
          "docker", "podman",    # Container
          "microk8s", "kubeadm", # Orchestrator
          "external"             # External Service (e.g. cloud database, PAAS)
        ], d_val.runtime)
      ]
    ]))
    error_message = "Dependency runtime contains invalid values. Refer to the documentation for details."
  }

  # Validate Provider Enum for Main Service.
  validation {
    condition = alltrue([
      for k, v in var.service_catalog : contains(["kvm", "aws", "gcp", "azure", "vmware"], v.provider)
    ])
    error_message = "Service provider must be one of: kvm, aws, gcp, azure, vmware."
  }

  # Validate Provider Enum for Dependency
  validation {
    condition = alltrue(flatten([
      for s_key, s_val in var.service_catalog : [
        for d_key, d_val in s_val.dependencies : contains(["kvm", "aws", "gcp", "azure", "vmware"], d_val.provider)
      ]
    ]))
    error_message = "Dependency provider must be one of: kvm, aws, gcp, azure, vmware."
  }

  # Validate Stage Enum for Main Service
  validation {
    condition = alltrue([
      for k, v in var.service_catalog : contains(["production", "staging", "development"], v.stage)
    ])
    error_message = "Service stage must be one of: production, staging, development."
  }

  # Validate CIDR Index for Main Service
  validation {
    condition = alltrue([
      for k, v in var.service_catalog : v.cidr_index > 124 && v.cidr_index < 255
    ])
    error_message = "Service cidr_index must be in range [125, 254]."
  }

  # Validate Global CIDR Index Uniqueness
  validation {
    condition = length(flatten([
      for k, v in var.service_catalog : concat(
        [v.cidr_index],
        [for d in values(v.dependencies) : d.cidr_index]
      )
      ])) == length(distinct(flatten([
        for k, v in var.service_catalog : concat(
          [v.cidr_index],
          [for d in values(v.dependencies) : d.cidr_index]
        )
    ])))
    error_message = "Duplicate 'cidr_index' detected! Every service and dependency must have a unique CIDR index to avoid network collision."
  }

  # Validate Start IP < End IP
  validation {
    condition = alltrue(flatten([
      for s in var.service_catalog : [
        s.ip_range.end_ip >= s.ip_range.start_ip,
        [for d in values(s.dependencies) : d.ip_range.end_ip >= d.ip_range.start_ip]
      ]
    ]))
    error_message = "Invalid reservation: 'end_ip' must be greater than or equal to 'start_ip'."
  }

  # Validate Boundary (1-254)
  validation {
    condition = alltrue(flatten([
      for s in var.service_catalog : [
        s.ip_range.start_ip > 0 && s.ip_range.end_ip < 255,
        [for d in values(s.dependencies) : d.ip_range.start_ip > 0 && d.ip_range.end_ip < 255]
      ]
    ]))
    error_message = "Reservation out of bounds: IPs must be between 1 and 254."
  }

  # Validate Service Key Format (DNS Safe: lowercase, numbers, hyphens)
  validation {
    condition = alltrue([
      for k, v in var.service_catalog : can(regex("^[a-z0-9-]+$", k))
    ])
    error_message = "Service names (keys) must only contain lowercase letters, numbers, and hyphens (DNS safe)."
  }

  # Validate Project Code Format
  validation {
    condition = alltrue([
      for k, v in var.service_catalog : can(regex("^[a-z0-9]+$", v.project_code))
    ])
    error_message = "Project code must only contain lowercase letters and numbers."
  }

  # Validate Component Subdomains Non-Empty
  validation {
    condition = alltrue(flatten([
      for k, v in var.service_catalog : [
        for c_k, c_v in v.components : length(c_v.subdomains) > 0
      ]
    ]))
    error_message = "Every component must define at least one subdomain."
  }

  # Validate Global Segment Key Uniqueness (Service vs. Service-Dependency)
  validation {
    condition = length(flatten([
      for k, v in var.service_catalog : concat(
        [k],
        [for d_k, d_v in v.dependencies : "${k}-${d_k}"]
      )
      ])) == length(distinct(flatten([
        for k, v in var.service_catalog : concat(
          [k],
          [for d_k, d_v in v.dependencies : "${k}-${d_k}"]
        )
    ])))
    error_message = "Naming collision detected in service keys! A Service name or Service-Dependency combination results in a duplicate segment key, which will cause network configuration failure."
  }
}
