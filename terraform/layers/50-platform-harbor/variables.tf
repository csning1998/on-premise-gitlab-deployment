
variable "trust_engine_config" {
  description = "Configuration for the Vault-based Trust Engine (Cert-Manager Issuer)"
  type = object({
    issuer_name           = string       # e.g., "vault-issuer"
    issuer_kind           = string       # e.g., "ClusterIssuer"
    authorized_namespaces = list(string) # e.g., ["cert-manager", "harbor"]
  })
  default = {
    issuer_name           = "vault-issuer"
    issuer_kind           = "ClusterIssuer"
    authorized_namespaces = ["cert-manager", "harbor"]
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

variable "ingress_class_name" {
  description = "Ingress class name"
  type        = string
  default     = "nginx"
}
