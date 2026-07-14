
variable "namespace_name" {
  description = "K8s namespace this tenant's own Alloy runs in"
  type        = string
}

variable "vault_endpoint" {
  description = "Vault API endpoint reachable from this cluster"
  type        = string
}

variable "vault_ca_bundle_b64" {
  description = "Base64-encoded bootstrap CA bundle for the SecretStore's Vault TLS verification"
  type        = string
}

variable "vault_auth_mount_path" {
  description = "Vault Kubernetes auth backend mount path for this tenant, e.g. kubernetes/gitlab/frontend"
  type        = string
}

variable "vault_role_name" {
  description = "Vault Kubernetes auth role name for this tenant, e.g. core-gitlab-frontend-role"
  type        = string
}

variable "vault_kv_key" {
  description = "Full Vault KV path to the tenant's minio_prometheus secret, e.g. <vault_kv_namespace>/gitlab/app/minio_prometheus"
  type        = string
}
