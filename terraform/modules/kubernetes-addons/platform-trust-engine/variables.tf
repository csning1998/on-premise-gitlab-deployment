
variable "api_server_connection" {
  description = "Connection information of Kubernetes API Server, used for Vault authentication callback"
  type = object({
    host    = string
    ca_cert = string
  })
}

variable "vault_config" {
  description = "Connection information of Vault"
  type = object({
    address   = string
    auth_path = string
    ca_cert   = optional(string)
  })
  default = {
    address   = ""
    auth_path = "kubernetes"
    ca_cert   = ""
  }
}

variable "issuer_config" {
  description = "Cert-Manager Issuer and Vault Role mapping configuration"
  type = object({
    name             = string       # ClusterIssuer in K8s, e.g., "vault-issuer"
    vault_role_name  = string       # Role name in Vault, e.g., "k8s-issuer-role"
    pki_mount_path   = string       # PKI Engine mount path in Vault, e.g., "pki/prod"
    issue_path       = string       # Issue path, usually "issue" or "sign"
  })
}

variable "reviewer_service_account" {
  description = "K8s Service Account for Vault Token Review"
  type = object({
    name      = string
    namespace = string
  })
  default = {
    name      = "vault-reviewer"
    namespace = "default"
  }
}

variable "helm_config" {
  description = "Cert-Manager Helm Chart installation configuration"
  type = object({
    install          = bool
    version          = string
    namespace        = string
    create_namespace = bool
    image_registry   = string
    image_repository = string
    chart_project    = string
  })
}
