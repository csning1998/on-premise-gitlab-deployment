
variable "helm_config" {
  description = "Helm Chart deployment configuration"
  type = object({
    version   = string
    namespace = string
    timeout   = number
  })
}

variable "gitlab_config" {
  description = "GitLab application configuration"
  type = object({
    hostname = string
    edition  = string
  })
}

variable "ingress_config" {
  description = "Ingress and Certificate configuration"
  type = object({
    class_name      = string
    tls_secret_name = string
    issuer_name     = string
    issuer_kind     = string
  })
}

variable "certificate_config" {
  description = "Configuration for GitLab Ingress Certificate"
  type = object({
    duration     = string
    renew_before = string
  })
}

variable "external_services" {
  description = "Connection details for external services"
  type = object({
    postgres = object({
      host       = string
      port       = string
      password   = string
      username   = string
      database   = string
      ssl_secret = optional(string)
    })
    redis = object({
      host     = string
      port     = string
      password = string
    })
    minio = object({
      hostname   = optional(string)
      ip         = optional(string)
      endpoint   = string
      access_key = string
      secret_key = string
      region     = string
      buckets = map(object({
        name       = string
        access_key = string
        secret_key = string
      }))
    })
  })
}

variable "gitlab_secrets" {
  description = "Internal secrets for Rails, Gitaly, etc."
  type = map(object({
    key   = string
    value = string
  }))
}

variable "ca_bundle" {
  description = "CA Bundle configuration"
  type = object({
    name        = string
    content     = string
    secret_name = string
  })
}
