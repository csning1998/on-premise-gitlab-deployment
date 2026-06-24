
variable "helm_config" {
  description = "Helm chart deployment configuration including OCI registry references"
  type = object({
    version          = string
    namespace        = string
    timeout          = number
    image_registry   = string
    chart_project    = string
    image_repository = string
  })
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.helm_config.version))
    error_message = "helm_config.version must be a stable semver string (e.g. 12.4.9)."
  }
}

variable "grafana_config" {
  description = "Grafana application configuration including FQDN and reference to K8s Secret holding admin credentials"
  type = object({
    fqdn                       = string
    admin_existing_secret_name = string
    dns_sans                   = list(string)
  })
}

variable "ingress_config" {
  description = "Ingress and TLS certificate configuration"
  type = object({
    class_name      = string
    tls_secret_name = string
    issuer_name     = string
    issuer_kind     = string
  })
}

variable "certificate_config" {
  description = "Certificate duration parameters passed to cert-manager ingress annotations"
  type = object({
    duration     = string
    renew_before = string
  })
}

variable "datasources_config" {
  description = "Internal Kubernetes service URLs for preconfigured Grafana datasources"
  type = object({
    mimir_url = string
    loki_url  = string
  })
}

variable "ca_bundle" {
  description = "Custom CA bundle Secret name to mount into Grafana for trusting internal PKI certificates"
  type = object({
    secret_name = string
  })
}
