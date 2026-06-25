
variable "trust_engine_config" {
  description = "Configuration for the Vault-based Trust Engine (Cert-Manager Issuer)"
  type = object({
    issuer_name           = string       # e.g., "vault-issuer"
    issuer_kind           = string       # e.g., "ClusterIssuer"
    authorized_namespaces = list(string) # e.g., ["cert-manager", "gitlab"]
  })
  default = {
    issuer_name           = "vault-issuer"
    issuer_kind           = "ClusterIssuer"
    authorized_namespaces = ["cert-manager", "gitlab"]
  }
}

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

variable "vault_dev_addr" {
  description = "The address of the Bootstrapper Vault (Podman Vault)"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "metric_server_config" {
  description = "Configuration for Metrics Server"
  type = object({
    version   = string
    namespace = string
  })
  default = {
    version   = "3.13.0"
    namespace = "kube-system"
  }
}

variable "csr_approver_config" {
  description = "Configuration for Kubelet CSR Approver"
  type = object({
    version        = string
    namespace      = string
    provider_regex = string
  })
  default = {
    version        = "1.2.14"
    namespace      = "kube-system"
    provider_regex = ""
  }
}

variable "ingress_nginx_config" {
  description = "Configuration for Ingress Nginx"
  type = object({
    version   = string
    namespace = string
  })
  default = {
    version   = "4.13.1"
    namespace = "ingress-nginx"
  }
}

variable "local_path_config" {
  description = "Configuration for Local Path Provisioner"
  type = object({
    version   = string
    namespace = string
  })
  default = {
    version   = "0.0.35"
    namespace = "kube-system"
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

variable "certificate_config" {
  description = "Configuration for GitLab Ingress Certificate"
  type = object({
    duration     = string
    renew_before = string
  })
  default = {
    duration     = "2160h" # 90 Days
    renew_before = "12h"   # Must be less than Vault's 24h declared duration.
  }
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

variable "alloy_version" {
  description = "Grafana Alloy Helm chart version"
  type        = string
  default     = "1.10.0"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.alloy_version))
    error_message = "alloy_version must be a stable semver string."
  }
}
