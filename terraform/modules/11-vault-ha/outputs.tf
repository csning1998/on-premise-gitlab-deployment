
output "tls_source_dir" {
  value       = abspath("${path.module}/tls")
  description = "The absolute path of the tls directory that Ansible needs to read the certificates from."
}
