
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
    loki_push_url         = string
  })
}

variable "vault_metrics_address" {
  description = "Optional host:port for Vault Prometheus metrics endpoint; when set, a dedicated prometheus.scrape component is added using /v1/sys/metrics path"
  type        = string
  nullable    = true
  default     = null
}

variable "vault_metrics_token_secret_name" {
  description = "Optional K8s Secret name holding the Vault token for authenticated sys/metrics access (replaces unauthenticated_metrics_access); mounted and referenced via bearer_token_file when vault_metrics_address is set"
  type        = string
  nullable    = true
  default     = null
}

variable "guest_scrape_targets" {
  description = "Optional static scrape targets for bare-metal guest VM metrics endpoints; each entry is inlined directly into the prometheus.scrape guest_scrape targets"
  type = list(object({
    address = string
    job     = string
    labels  = optional(map(string), {})
  }))
  default = []
}

variable "workhorse_scrape_enabled" {
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

variable "minio_metrics_token_secret_name" {
  description = "Optional K8s Secret name holding the MinIO Prometheus JWT (replaces MINIO_PROMETHEUS_AUTH_TYPE=public); mounted and referenced via bearer_token_file when minio_scrape_targets is set"
  type        = string
  nullable    = true
  default     = null
}

variable "haproxy_stats_basic_auth_secret_name" {
  description = "Optional K8s Secret name holding the HAProxy stats listener's Basic Auth password (key: password); mounted and referenced via basic_auth.password_file when the HAProxy stats target is scraped"
  type        = string
  nullable    = true
  default     = null
}

variable "haproxy_scrape_targets" {
  description = "Optional HAProxy stats listener addresses for metrics scraping at /metrics over HTTPS with Basic Auth; uses the Alloy CA bundle for server certificate verification"
  type = list(object({
    address = string
    job     = string
    labels  = optional(map(string), {})
  }))
  default = []
}

variable "blackbox_targets" {
  description = "Optional endpoints to probe via Alloy's embedded blackbox exporter (prometheus.exporter.blackbox). module selects the prober: http_2xx (internal HTTPS verified against the ca-bundle mount), http_2xx_public (external HTTPS verified against the system trust store), or tcp_connect (L4 reachability for non-HTTPS VIPs). probe_ssl_earliest_cert_expiry is a byproduct of every HTTPS probe."
  type = list(object({
    name    = string
    address = string
    module  = optional(string, "http_2xx")
  }))
  default = []
}
