
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

variable "harbor_helm_config" {
  description = "Configuration for Harbor Helm Chart Deployment"
  type = object({
    version         = string
    namespace       = string
    ingress_class   = string
    tls_secret_name = string
    notary_prefix   = string
  })
}

variable "object_storage_config" {
  description = "Configuration for S3 Object Storage used by Harbor"
  type = object({
    bucket_name = string
    region      = string
  })
}

variable "certificate_config" {
  description = "Configuration for Harbor Ingress Certificate"
  type = object({
    duration     = string
    renew_before = string
  })
  default = {
    duration     = "2160h"
    renew_before = "12h" # Must be less than Vault's 24h declared duration.
  }
}
