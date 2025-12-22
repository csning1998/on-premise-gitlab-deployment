
# Allow Cert-Manager's ServiceAccount to login Vault
resource "vault_kubernetes_auth_backend_role" "issuer" {
  backend                          = vault_kubernetes_auth_backend_config.config.backend
  role_name                        = "harbor-issuer"
  bound_service_account_names      = ["default"]           # Cert-Manager Issuer uses default SA
  bound_service_account_namespaces = ["cert-manager"]      # Limit Namespace
  token_policies                   = ["harbor-pki-policy"] # Layer 10 created policy
}

# Create ClusterIssuer (K8s resource) that is interface Cert-Manager uses to issue certificates, pointing to Vault
resource "kubernetes_manifest" "vault_issuer" {
  depends_on = [helm_release.cert_manager, vault_kubernetes_auth_backend_role.issuer]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "vault-issuer"
    }
    spec = {
      vault = {
        path     = "pki/prod/sign/harbor-ingress-role" # Layer 10 defined role path
        server   = "https://vault.iac.local:8200"
        caBundle = base64encode(data.terraform_remote_state.vault.outputs.vault_ca_cert)

        auth = {
          kubernetes = {
            mountPath = "kubernetes"
            role      = "harbor-issuer"
            secretRef = {
              name = "vault-issuer-token"
              key  = "token"
            }
          }
        }
      }
    }
  }
}

# Declare Harbor certificate (K8s resource)
resource "kubernetes_manifest" "harbor_certificate" {
  depends_on = [kubernetes_manifest.vault_issuer, kubernetes_namespace.harbor]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "harbor-ingress-cert"
      namespace = kubernetes_namespace.harbor.metadata[0].name
    }
    spec = {
      secretName = "harbor-ingress-tls" # Generated Secret Name
      issuerRef = {
        name = "vault-issuer"
        kind = "ClusterIssuer"
      }
      commonName  = var.harbor_hostname
      dnsNames    = [var.harbor_hostname]
      duration    = "2160h" # 90 Days
      renewBefore = "360h"  # 15 Days
    }
  }
}
