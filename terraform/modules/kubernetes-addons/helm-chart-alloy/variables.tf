
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
    error_message = "helm_config.version must be a stable semver string (e.g. 0.9.2)."
  }
}

variable "alloy_config" {
  description = "Alloy metrics collection configuration including remote write target, cluster identity label, Mimir tenant ID, optional mTLS client certificate secret name, and optional CA bundle secret name for external TLS verification"
  type = object({
    remote_write_url      = string
    cluster_label         = string
    tenant_id             = string
    mtls_cert_secret_name = optional(string, null)
    ca_bundle_secret_name = optional(string, null)
  })
}

variable "vault_metrics_address" {
  description = "Optional host:port for Vault Prometheus metrics endpoint; when set, a dedicated prometheus.scrape component is added using /v1/sys/metrics path"
  type        = string
  nullable    = true
  default     = null
}

# TODO rename to static_scrape_targets for naming consistency with alloy_config (Phase 3+ naming MR)
variable "vm_static_targets" {
  description = "Optional static scrape targets for bare-metal VM metrics endpoints; each entry is inlined directly into prometheus.scrape vm_static targets"
  type = list(object({
    address = string
    job     = string
    labels  = optional(map(string), {})
  }))
  default = []
}

variable "workhorse_targets" {
  description = "When true, adds a dedicated scrape path for gitlab-workhorse's metrics endpoint (port 9229), which cannot share the webservice pod's prometheus.io/* annotation (already pointed at port 8083) since a pod carries only one such annotation set. Selects pods by the app=webservice label instead of annotation, so it stays correct as pod IPs churn."
  type        = bool
  default     = false
}

variable "keycloak_metrics_address" {
  description = "Optional host:port for Keycloak management metrics endpoint; when set, a prometheus.scrape component is added using /metrics path over HTTPS with ca-bundle verification"
  type        = string
  nullable    = true
  default     = null
}

variable "minio_scrape_targets" {
  description = "Optional MinIO node addresses for per-node metrics scraping at /minio/v2/metrics/node over HTTPS; uses the Alloy mTLS CA for server certificate verification"
  type = list(object({
    address = string
    job     = string
    labels  = optional(map(string), {})
  }))
  default = []
}
