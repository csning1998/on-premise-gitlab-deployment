
# Establish Service Account (Vault uses this identity to verify K8s)
resource "kubernetes_service_account" "vault_issuer" {
  depends_on = [helm_release.cert_manager]

  metadata {
    name      = "vault-issuer"
    namespace = "cert-manager" # Ensure this matches where Cert-Manager is installed
  }
}

# Create Long-Lived Token Secret
resource "kubernetes_secret" "vault_issuer_token" {
  metadata {
    name      = "vault-issuer-token"
    namespace = "cert-manager"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.vault_issuer.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token" # JWT Token will be automatically filled in by K8s Controller
}

# Define ClusterIssuer
resource "kubectl_manifest" "vault_issuer" {
  depends_on = [
    helm_release.cert_manager,
    kubernetes_secret.vault_issuer_token
  ]

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "vault-issuer"
    }
    spec = {
      vault = {
        server   = "https://${data.terraform_remote_state.vault_core.outputs.vault_ha_virtual_ip}:443"
        caBundle = base64encode(data.terraform_remote_state.vault_core.outputs.vault_ca_cert)
        path     = "pki/prod/sign/harbor-ingress-role"

        auth = {
          kubernetes = {
            mountPath = "kubernetes"
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

# Allow Cert-Manager's ServiceAccount to login Vault
resource "vault_kubernetes_auth_backend_role" "issuer" {
  backend                          = "kubernetes"
  role_name                        = "harbor-issuer"
  bound_service_account_names      = [kubernetes_service_account.vault_issuer.metadata[0].name]
  bound_service_account_namespaces = ["cert-manager"]      # Limit Namespace
  token_policies                   = ["harbor-pki-policy"] # Layer 10 created policy
}

