
# terraform/layers/60-gitlab-service/variables.tf

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
