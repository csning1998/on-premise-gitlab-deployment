
variable "cert_manager_config" {
  description = "Configuration for Cert-Manager Helm Chart"
  type = object({
    version   = string # e.g., "v1.14.0"
    namespace = string # e.g., "cert-manager"
  })
  default = {
    version   = "v1.14.0"
    namespace = "cert-manager"
  }
}

variable "gitlab_helm_config" {
  description = "Configuration for GitLab Helm Chart Deployment"
  type = object({
    version         = string
    namespace       = string
    ingress_class   = string
    tls_secret_name = string
  })
}

variable "enable_db_token_reset" {
  description = "Enable the one-time Kubernetes Job to clean encrypted database fields and bypass CipherError"
  type        = bool
  default     = false
}

variable "gitlab_version" {
  description = "The version of GitLab to deploy"
  type        = string
  default     = "v18.8.2"
}

variable "enable_ci_signing_key_rotation" {
  description = "Enable the one-time Kubernetes Job that overwrites ApplicationSetting.ci_job_token_signing_key with the Vault-sourced RSA key. Reset to false after the job completes."
  type        = bool
  default     = false
}

variable "ci_signing_key_rotation_version" {
  description = "Increment this integer each time a new CI signing key rotation Job must be created. Terraform uses this as part of the Job name to force resource recreation."
  type        = number
  default     = 1
}

variable "enable_gitlab_pat_automation" {
  description = "Enable the Kubernetes Job that generates or renews the GitLab root PAT used by 60-provision-gitlab-platform's provider, writing it to Vault."
  type        = bool
  default     = false
}

variable "gitlab_pat_ttl_days" {
  description = "Expiry, in days, for the generated PAT. GitLab enforces a mandatory expiry on all personal access tokens (365-day self-managed maximum); this only needs to be shorter than that ceiling, since the job re-validates and regenerates the token on every run where it has expired."
  type        = number
  default     = 90
}

variable "gitlab_pat_automation_version" {
  description = "Increment this integer to force recreation of the PAT automation Job."
  type        = number
  default     = 1
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
