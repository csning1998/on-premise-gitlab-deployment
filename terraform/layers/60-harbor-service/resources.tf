
# Get PKI CA from Vault
data "http" "vault_pki_ca" {
  url         = "https://${data.terraform_remote_state.vault_pki.outputs.vault_ha_virtual_ip}:443/v1/pki/prod/ca/pem"
  ca_cert_pem = data.terraform_remote_state.vault_pki.outputs.vault_ca_cert
}

# Add PKI CA to Bundle
resource "kubernetes_secret" "harbor_ca_bundle" {
  metadata {
    name      = "harbor-ca-bundle"
    namespace = "harbor"
  }

  data = {
    "ca.crt" = join("\n", [
      data.terraform_remote_state.vault_pki.outputs.vault_ca_cert,
      data.http.vault_pki_ca.response_body
    ])
  }
}
