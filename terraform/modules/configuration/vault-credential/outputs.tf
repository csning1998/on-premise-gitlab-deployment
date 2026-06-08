
output "path" {
  description = "Vault KV mount-relative path for cross-layer ephemeral reads"
  value       = vault_kv_secret_v2.this.name
}

output "credentials" {
  description = "All credentials (generated + static) keyed by name"
  value = merge(
    var.static,
    { for k, v in random_password.this : k => v.result }
  )
  sensitive = true
}
