
# 6. Establish Issuer SA since Cert-Manager uses this identity to login Vault
resource "kubernetes_service_account" "vault_issuer" {
  depends_on = [helm_release.cert_manager]

  metadata {
    name      = "vault-issuer"
    namespace = "cert-manager"
  }
}

# 7. Create Long-Lived Token Secret
resource "kubernetes_secret" "vault_issuer_token" {
  metadata {
    name      = "vault-issuer-token"
    namespace = "cert-manager"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.vault_issuer.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

# 8. Define ClusterIssuer (use kubectl provider to avoid CRD issue)
resource "kubectl_manifest" "vault_issuer" {
  depends_on = [
    helm_release.cert_manager,
    kubernetes_secret.vault_issuer_token,
    vault_kubernetes_auth_backend_role.issuer
  ]

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "vault-issuer"
    }
    spec = {
      vault = {
        server   = "https://${data.terraform_remote_state.vault_pki.outputs.vault_ha_virtual_ip}:443"
        caBundle = base64encode(data.terraform_remote_state.vault_pki.outputs.vault_ca_cert)
        path     = "pki/prod/sign/harbor-ingress-role"

        auth = {
          kubernetes = {
            mountPath = "/v1/auth/kubernetes"
            role      = "harbor-issuer"
            secretRef = {
              name = kubernetes_secret.vault_issuer_token.metadata[0].name
              key  = "token"
            }
          }
        }
      }
    }
  })
}
