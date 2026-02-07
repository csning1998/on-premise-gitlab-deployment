
variable "trust_engine_config" {
  description = "Configuration for the Vault-based Trust Engine (Cert-Manager Issuer)"
  type = object({
    issuer_name           = string       # e.g., "vault-issuer"
    issuer_kind           = string       # e.g., "ClusterIssuer"
    authorized_namespaces = list(string) # e.g., ["cert-manager", "harbor"]
  })
}

variable "cert_manager_config" {
  description = "Configuration for Cert-Manager Helm Chart"
  type = object({
    version   = string # e.g., "v1.14.0"
    namespace = string # e.g., "cert-manager"
  })
}

variable "db_init_config" {
  description = "Configuration for Harbor Database Initialization"
  type = object({
    db_name = string # e.g., "registry"
    db_user = string # e.g., "harbor"
  })
}

variable "microk8s_api_port" {
  description = "MicroK8s API Port"
  type        = string
  default     = "16443"
}
