
/**
 * foundation-metadata: Variables
 *
 * This file defines the Input Schema for this project's service catalog and
 * its cross-project access to meta-platform's global metadata. Downstream
 * layers consume the outputs generated based on these variables.
 *
 * Requirements:
 * 1. gitlab_token: PAT used to read meta-platform's foundation-metadata state.
 * 2. service_catalog: Mapping of all services and their components.
 */

variable "gitlab_token" {
  description = "GitLab Personal Access Token (PAT) with api scope, used only to read meta-platform's remote state. The project token in backend-state.json is scoped to this repository alone and cannot reach a different project's state."
  type        = string
  sensitive   = true
}

variable "gitlab_username" {
  description = "GitLab account name paired with gitlab_token for the meta-platform remote state HTTP backend."
  type        = string
}

variable "service_catalog_module_source" {
  description = "Source address of the service-catalog module in the GitLab Terraform Module Registry."
  type        = string
  const       = true
}

variable "service_catalog_module_version" {
  description = "Version constraint applied to the service-catalog module fetched from the GitLab Terraform Module Registry."
  type        = string
  const       = true
}

variable "vault_kv_namespace" {
  description = "Project-level Vault KV namespace used as path prefix for all generated credentials."
  type        = string
}

variable "harbor_registry_proxies" {
  description = "Harbor upstream registry proxy cache and OCI project definitions."
  type = object({
    proxy_oci = map(object({
      name = string
    }))
    proxy_caches = map(object({
      registry_name = string
      endpoint_url  = string
      provider_name = string
      project_name  = string
    }))
  })
}

variable "service_catalog" {
  description = "The Single Source of Truth (SSoT) for all services, component, ingress, and dependencies."
  type = map(object({
    owner        = string
    project_code = string
    stage        = string

    components = map(object({
      provider    = string
      runtime     = string
      cidr_index  = number
      tags        = optional(list(string), [])
      node_groups = optional(list(string), [])
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
    }))
  }))

  # Validate Runtime Enum
  validation {
    condition = alltrue(flatten([
      for s in var.service_catalog : [
        for c in s.components : contains([
          "baremetal", "docker", "podman", "microk8s", "kubeadm", "minikube", "external"
        ], c.runtime)
      ]
    ]))
    error_message = "Component runtime contains invalid values."
  }

  # Validate Provider Enum
  validation {
    condition = alltrue(flatten([
      for s in var.service_catalog : [
        for c in s.components : contains(["kvm", "aws", "gcp", "azure", "vmware"], c.provider)
      ]
    ]))
    error_message = "Component provider must be one of: kvm, aws, gcp, azure, vmware."
  }

  # Validate Stage Enum
  validation {
    condition = alltrue([
      for k, v in var.service_catalog : contains(["production", "staging", "development"], v.stage)
    ])
    error_message = "Service stage must be one of: production, staging, development."
  }

  # Validate CIDR Index Requirements
  validation {
    condition = alltrue(flatten([
      for s in var.service_catalog : [
        for c in s.components : c.cidr_index > 124 && c.cidr_index < 255
      ]
    ]))
    error_message = "Component cidr_index must be in range [125, 254]."
  }

  # Validate Global CIDR Index Uniqueness
  validation {
    condition = length(flatten([
      for s in var.service_catalog : [
        for c in s.components : c.cidr_index
      ]
      ])) == length(distinct(flatten([
        for s in var.service_catalog : [
          for c in s.components : c.cidr_index
        ]
    ])))
    error_message = "Duplicate 'cidr_index' detected! Every component must have a unique CIDR index to avoid network collision."
  }

  # Validate Start IP < End IP
  validation {
    condition = alltrue(flatten([
      for s in var.service_catalog : [
        for c in s.components : c.ip_range.end_ip >= c.ip_range.start_ip
      ]
    ]))
    error_message = "Invalid reservation: 'end_ip' must be greater than or equal to 'start_ip'."
  }

  # Validate Boundary (1-254)
  validation {
    condition = alltrue(flatten([
      for s in var.service_catalog : [
        for c in s.components : c.ip_range.start_ip > 0 && c.ip_range.end_ip < 255
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

  # Validate Ingress Subdomains Non-Empty
  # Every ingress entry must have at least one valid subdomain to ensure DNS generation.
  validation {
    condition = alltrue(flatten([
      for k, s in var.service_catalog : [
        for c_k, c in s.components : [
          for i_k, i_v in coalesce(c.ingress, {}) : length(i_v.subdomains) > 0
        ]
      ]
    ]))
    error_message = "Every ingress entry must define at least one subdomain."
  }
}
