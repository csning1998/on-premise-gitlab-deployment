
output "secret_name" {
  value = kubernetes_secret.harbor_tls.metadata[0].name
}

output "ca_cert_pem" {
  value = tls_self_signed_cert.ca.cert_pem
}
