
variable "gitlab_runner_config" {
  description = "Configuration for GitLab Runner Helm deployment"
  type = object({
    namespace = string
    version   = string
  })
  default = {
    namespace = "gitlab"
    version   = "0.85.0"
  }
}

variable "alloy_version" {
  description = "Grafana Alloy Helm chart version"
  type        = string
  default     = "1.10.0"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.alloy_version))
    error_message = "alloy_version must be a stable semver string."
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
