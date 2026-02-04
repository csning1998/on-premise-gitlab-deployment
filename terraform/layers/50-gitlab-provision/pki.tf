

# Ingress Certificate
resource "vault_pki_secret_backend_cert" "gitlab_ingress_cert" {
  backend = data.terraform_remote_state.vault_core.outputs.pki_configuration.vault_pki_path
  name    = data.terraform_remote_state.vault_core.outputs.pki_configuration.ingress_roles.gitlab

  common_name = data.terraform_remote_state.vault_core.outputs.pki_configuration.ingress_domains.gitlab[0]
  ttl         = "2160h"
}

# Inject Certificate to Kubernetes
resource "kubernetes_secret" "gitlab_tls" {
  metadata {
    name      = "gitlab-tls"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = join("\n", [
      vault_pki_secret_backend_cert.gitlab_ingress_cert.certificate,
      vault_pki_secret_backend_cert.gitlab_ingress_cert.ca_chain
    ])
    "tls.key" = vault_pki_secret_backend_cert.gitlab_ingress_cert.private_key
  }
}

resource "kubernetes_secret" "gitlab_custom_ca" {
  metadata {
    name      = "gitlab-custom-ca"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "vault-api-ca.crt"    = data.terraform_remote_state.vault_core.outputs.vault_ca_cert
    "internal-pki-ca.crt" = data.terraform_remote_state.vault_core.outputs.internal_pki_ca_cert
  }
}
