
variable "trust_engine_config" {
  description = "Configuration for the Vault-based Trust Engine (Cert-Manager Issuer)"
  type = object({
    issuer_name           = string
    issuer_kind           = string
    authorized_namespaces = list(string)
  })
  default = {
    issuer_name           = "vault-issuer"
    issuer_kind           = "ClusterIssuer"
    authorized_namespaces = ["cert-manager", "observability"]
  }
}

variable "ingress_class_name" {
  description = "Ingress class name"
  type        = string
  default     = "nginx"
}

variable "certificate_config" {
  description = "Configuration for Ingress Certificate duration"
  type = object({
    duration     = string
    renew_before = string
  })
  default = {
    duration     = "2160h"
    renew_before = "12h"
  }
}

variable "observability_stack_config" {
  description = "Helm chart versions and shared namespace for the Grafana, Mimir, and Loki observability stack"
  type = object({
    grafana_version = string
    mimir_version   = string
    loki_version    = string
    namespace       = string
  })
  default = {
    grafana_version = "12.4.9"
    mimir_version   = "6.0.6"
    loki_version    = "17.4.10"
    namespace       = "observability"
  }
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.observability_stack_config.grafana_version))
    error_message = "observability_stack_config.grafana_version must be a stable semver string."
  }
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.observability_stack_config.mimir_version))
    error_message = "observability_stack_config.mimir_version must be a stable semver string."
  }
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.observability_stack_config.loki_version))
    error_message = "observability_stack_config.loki_version must be a stable semver string."
  }
}
