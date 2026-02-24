
variable "cluster_name" {
  description = "The unique name of the cluster (e.g. gitlab-core)"
  type        = string
}

variable "service_vip" {
  type = string
}

variable "service_domain" {
  description = "The FQDN for the Load Balancer service"
  type        = string
}

variable "service_ports" {
  description = "Port mappings for the service"
  type = map(object({
    frontend_port = number
    backend_port  = number
  }))
}

variable "topology_cluster" {
  description = "Standardized compute topology supporting multi-component architecture."
  type = object({
    storage_pool_name = string
    components        = map(any) # simplified to match Redis implementation
  })
}

variable "network_parameters" {
  description = "Map of L3 network configurations keyed by tier name."
  type = map(object({
    network = object({
      nat = object({
        gateway = string,
        cidrv4  = string,
        dhcp    = optional(any)
      })
      hostonly = object({
        gateway = string,
        cidrv4  = string
      })
    })
    network_access_scope = string
  }))
}

variable "network_bindings" {
  description = "Map of L2 network bindings keyed by tier name."
  type = map(object({
    nat_net_name         = string
    nat_bridge_name      = string
    hostonly_net_name    = string
    hostonly_bridge_name = string
  }))
}

variable "security_pki_bundle" {
  description = "PKI certificates passed from Layer 00 via Layer 10"
  type        = any
  default     = null
}

variable "credentials_system" {
  description = "System level credentials (ssh user, password, keys)"
  sensitive   = true
  type = object({
    username             = string
    password             = string
    ssh_public_key_path  = string
    ssh_private_key_path = string
  })
}

variable "credentials_db" {
  description = "Database level credentials (patroni, replication)"
  sensitive   = true
  type = object({
    minio_root_user     = string
    minio_root_password = string
    minio_vrrp_secret   = string
  })
}

variable "credentials_vault_agent" {
  description = "Vault Agent Configuration"
  sensitive   = true
  type = object({
    role_id       = string
    secret_id     = string
    ca_cert_b64   = string
    role_name     = string # PKI Role Name
    vault_address = string
    common_name   = string
  })
}
