

variable "ingress_class_name" {
  description = "Ingress class name"
  type        = string
  default     = "nginx"
}


variable "observability_stack_config" {
  description = "Helm chart versions, namespace, and cluster identity for the Grafana, Mimir, Loki, and Alloy observability stack"
  type = object({
    grafana_version = string
    mimir_version   = string
    loki_version    = string
    alloy_version   = string
    namespace       = string
    cluster_name    = string
  })
  default = {
    grafana_version = "12.4.9"
    mimir_version   = "6.0.6"
    loki_version    = "17.4.10"
    alloy_version   = "1.10.0"
    namespace       = "observability"
    cluster_name    = "observability"
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
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.observability_stack_config.alloy_version))
    error_message = "observability_stack_config.alloy_version must be a stable semver string."
  }
}

variable "kube_state_metrics_version" {
  description = "kube-state-metrics Helm chart version"
  type        = string
  default     = "7.8.1"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.kube_state_metrics_version))
    error_message = "kube_state_metrics_version must be a stable semver string."
  }
}
