
output "tls_source_dir" {
  description = "The directory where certificates were saved."
  value       = var.output_dir

  depends_on = [
    local_file.vault_ca,
    local_file.vault_server_crt,
    local_file.vault_server_key
  ]
}

output "ca_cert_file" {
  description = "Absolute path to the generated CA certificate file."
  value       = "${var.output_dir}/vault-ca.crt"

  depends_on = [local_file.vault_ca]
}

output "ca_cert_pem" {
  description = "The CA certificate PEM content."
  value       = var.tls_mode == "generated" ? tls_self_signed_cert.vault_ca[0].cert_pem : ""
}
