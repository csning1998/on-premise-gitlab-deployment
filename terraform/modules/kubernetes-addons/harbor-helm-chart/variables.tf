
variable "helm_config" {
  description = "Helm Chart deployment configuration"
  type = object({
    version   = string
    namespace = string
    timeout   = number
  })
}

variable "harbor_config" {
  description = "Harbor application configuration"
  type = object({
    hostname       = string
    notary_prefix  = string
    admin_password = string
    secret_key     = string # 用於內部加密 (core-secret)
  })
}

variable "ingress_config" {
  description = "Ingress and Certificate configuration"
  type = object({
    class_name      = string
    tls_secret_name = string
    issuer_name     = string # ClusterIssuer Name
    issuer_kind     = string # ClusterIssuer Kind
  })
}

variable "certificate_config" {
  description = "Configuration for Harbor Ingress Certificate"
  type = object({
    duration     = string
    renew_before = string
  })
}

variable "external_services" {
  description = "Connection details for external services (Postgres, Redis, S3)"
  type = object({
    postgres = object({
      host     = string
      port     = string
      password = string
    })
    redis = object({
      host     = string
      password = string
    })
    s3 = object({
      bucket     = string
      region     = string
      access_key = string
      secret_key = string
      endpoint   = string
    })
  })
}

variable "ca_bundle" {
  description = "CA Bundle configuration"
  type = object({
    name        = string
    content     = string
    secret_name = string
  })
}
