
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
    authorized_namespaces = ["gitlab"] # Restricted to GitLab application namespace
  }
}

variable "cert_manager_config" {
  description = "Configuration for Cert-Manager Helm Chart"
  type = object({
    version   = string
    namespace = string
  })
  default = {
    version   = "v1.14.0"
    namespace = "cert-manager"
  }
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
