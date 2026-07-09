
# SSoT metadata inputs (type = any: terraform_remote_state outputs carry no static schema)
variable "global_topology_identity" {
  description = "SSoT topology identity map from Layer 00 metadata."
  type        = any
}

variable "global_topology_network" {
  description = "SSoT topology network map from Layer 00 metadata."
  type        = any
}

variable "global_pki_map" {
  description = "PKI role map from Layer 00 metadata."
  type        = any
}

variable "global_network_baseline" {
  description = "Global network baseline parameters (MSS, MTU, Node Exporter port) from Layer 00 metadata."
  type = object({
    global_mss         = number
    global_mtu         = number
    node_exporter_port = number
  })
}

variable "global_vault_pki_b64" {
  description = "Bootstrap PKI certificates in base64 from metadata layer. Null when PKI not yet initialized."
  type = object({
    server_cert_b64 = string
    server_key_b64  = string
    ca_cert_b64     = string
  })
  default = null
}

variable "infrastructure_map" {
  description = "Physical network infrastructure map from Layer 10 handover. type = any: remote_state output."
  type        = any
}

# Vault integration inputs (optional — only required for 30-* layers with Vault Agent)
variable "vault_sys_vip" {
  description = "Vault system VIP for sys_vault_endpoint construction. Required for layers with Vault Agent integration."
  type        = string
  default     = null
}

variable "vault_pki_outputs" {
  description = "Full outputs of the vault_pki layer. type = any: remote_state output with dynamic PKI role keys."
  type        = any
  default     = null
}

# Targeting
variable "target_clusters" {
  description = "Map of role to physical cluster name from SSoT."
  type        = map(string)

  validation {
    condition     = length(var.target_clusters) > 0
    error_message = "target_clusters must contain at least one entry."
  }
}

variable "primary_role" {
  description = "Primary role key within target_clusters."
  type        = string
}

variable "service_config" {
  description = "Compute topology per role. Keys must match target_clusters keys."
  type = map(object({
    role            = string
    network_tier    = optional(string, "default")
    base_image_path = string
    nodes = map(object({
      ip_suffix            = number
      vcpu                 = number
      ram_size             = number
      os_disk_capacity_gib = optional(number)
      cpu_mode             = optional(string, null)
      attached_volumes = optional(list(object({
        pool   = string
        volume = string
      })), [])
    }))
  }))
}

variable "guest_vm_data" {
  description = "Raw VM credential key-value pairs from Vault secret."
  type        = map(string)
  sensitive   = true
}
