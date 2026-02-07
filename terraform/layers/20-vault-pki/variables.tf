
variable "service_catalog" {
  description = "Universal Service Definitions. Runtime = Tech Stack (docker/k8s), Stage = Lifecycle (prod/dev)."
  type = map(object({
    runtime = string
    stage   = string
    tag     = optional(string)

    components = map(object({
      subdomains = list(string)
    }))

    dependencies = map(object({
      service_name = string
      runtime      = string
      tag          = optional(string)
    }))
  }))
}

variable "vault_auth_backends" {
  description = "Map of Auth Backends to enable (e.g., approle, kubernetes)"
  type = map(object({
    type = string
    path = string
  }))
}

variable "vault_pki_engine_config" {
  description = "Configuration for the PKI Secrets Engine"
  type = object({
    path                = string
    root_ca_common_name = string

    default_lease_ttl_seconds = number
    max_lease_ttl_seconds     = number
  })
}
