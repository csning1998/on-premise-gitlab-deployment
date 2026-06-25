
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
    authorized_namespaces = ["cert-manager", "harbor", "observability"]
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
