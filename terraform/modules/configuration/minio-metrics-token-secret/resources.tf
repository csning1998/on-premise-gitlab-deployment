
resource "kubernetes_manifest" "observability_vault_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "observability-vault-store"
      namespace = var.namespace_name
    }
    spec = {
      provider = {
        vault = {
          server   = var.vault_endpoint
          path     = "secret"
          version  = "v2"
          caBundle = var.vault_ca_bundle_b64
          auth = {
            kubernetes = {
              mountPath = var.vault_auth_mount_path
              role      = var.vault_role_name
              serviceAccountRef = {
                name = "default"
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "minio_metrics_token_external_secret" {
  depends_on = [kubernetes_manifest.observability_vault_secret_store]

  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "alloy-minio-metrics-token"
      namespace = var.namespace_name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "observability-vault-store"
        kind = "SecretStore"
      }
      target = {
        name           = "alloy-minio-metrics-token"
        creationPolicy = "Owner"
      }
      data = [{
        secretKey = "token"
        remoteRef = {
          key      = var.vault_kv_key
          property = "bearer_token"
        }
      }]
    }
  }
}
