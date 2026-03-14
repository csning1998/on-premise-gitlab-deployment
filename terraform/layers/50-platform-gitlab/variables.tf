
variable "trust_engine_config" {
  description = "Configuration for the Vault-based Trust Engine (Cert-Manager Issuer)"
  type = object({
    issuer_name           = string       # e.g., "vault-issuer"
    issuer_kind           = string       # e.g., "ClusterIssuer"
    authorized_namespaces = list(string) # e.g., ["cert-manager", "gitlab"]
  })
  default = {
    issuer_name           = "vault-issuer"
    issuer_kind           = "ClusterIssuer"
    authorized_namespaces = ["cert-manager", "gitlab"]
  }
}

variable "cert_manager_config" {
  description = "Configuration for Cert-Manager Helm Chart"
  type = object({
    version   = string # e.g., "v1.14.0"
    namespace = string # e.g., "cert-manager"
  })
  default = {
    version   = "v1.14.0"
    namespace = "cert-manager"
  }
}

variable "vault_dev_addr" {
  description = "The address of the Bootstrapper Vault (Podman Vault)"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "metric_server_config" {
  description = "Configuration for Metrics Server"
  type = object({
    version   = string
    namespace = string
  })
  default = {
    version   = "3.13.0"
    namespace = "kube-system"
  }
}

variable "ingress_nginx_config" {
  description = "Configuration for Ingress Nginx"
  type = object({
    version   = string
    namespace = string
  })
  default = {
    version   = "4.13.1"
    namespace = "ingress-nginx"
  }
}

variable "local_path_config" {
  description = "Configuration for Local Path Provisioner"
  type = object({
    version   = string
    namespace = string
  })
  default = {
    version   = "0.0.35"
    namespace = "kube-system"
  }
}
