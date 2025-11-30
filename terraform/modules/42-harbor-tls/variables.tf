
variable "cert_common_name" {
  description = "The Common Name for the certificate"
  type        = string
}

variable "namespace" {
  description = "The Kubernetes namespace to store the TLS secret"
  type        = string
}

variable "secret_name" {
  description = "The name of the K8s Secret to create"
  type        = string
  default     = "harbor-ingress-tls"
}

variable "dns_names" {
  description = "List of DNS names for Subject Alternative Names"
  type        = list(string)
  default     = []
}

variable "organization" {
  description = "The organization for the certificate"
  type        = string
  default     = "on-premise-gitlab-deployment"
}

variable "common_name_subject" {
  description = "The Common Name for the certificate"
  type        = string
  default     = "Harbor Root CA"
}
