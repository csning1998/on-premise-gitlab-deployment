
output "path" {
  description = "Vault KV mount-relative path for cross-layer ephemeral reads"
  value       = vault_kv_secret_v2.this.name
}

output "credentials" {
  # Callers MUST NOT reference this output in any non-sensitive context (e.g., a tag value).
  # Prior to Terraform 1.5, the sensitive marking of a module output does not propagate into the calling module's state.
  description = "All credentials (generated + static) keyed by name"
  value = merge(
    var.static,
    { for k, v in random_password.this : k => v.result }
  )
  sensitive = true
}
