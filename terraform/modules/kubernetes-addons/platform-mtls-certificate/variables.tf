
variable "name" {
  description = "The name of the certificate and the resulting secret."
  type        = string
}

variable "namespace" {
  description = "The Kubernetes namespace where the certificate and secret will reside."
  type        = string
}

variable "common_name" {
  description = "The common name for the certificate."
  type        = string
}

variable "dns_sans" {
  description = "List of DNS Subject Alternative Names."
  type        = list(string)
  default     = []
}

variable "issuer_name" {
  description = "The name of the cert-manager issuer."
  type        = string
}

variable "issuer_kind" {
  description = "The kind of the cert-manager issuer (e.g., Issuer or ClusterIssuer)."
  type        = string
  default     = "ClusterIssuer"
}

variable "duration" {
  description = "The duration of the certificate (e.g., 24h)."
  type        = string
  default     = "24h"
}

variable "renew_before" {
  description = "How long before expiry the certificate should be renewed (e.g., 12h)."
  type        = string
  default     = "12h"
}
