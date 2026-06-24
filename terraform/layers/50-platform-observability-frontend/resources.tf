
resource "kubernetes_secret" "ca_bundle" {
  metadata {
    name      = local.ca_bundle_config.secret_name
    namespace = kubernetes_namespace.observability.metadata[0].name
  }
  data = {
    "ca.crt" = local.ca_bundle_config.content
  }
  depends_on = [kubernetes_namespace.observability]
}

resource "kubernetes_manifest" "observability_vault_secret_store" {
  depends_on = [kubernetes_namespace.observability]

  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "observability-vault-store"
      namespace = kubernetes_namespace.observability.metadata[0].name
    }
    spec = {
      provider = {
        vault = {
          server   = local.vault_address
          path     = "secret"
          version  = "v2"
          caBundle = local.state.vault_pki.bootstrap_ca_b64.content_b64
          auth = {
            kubernetes = {
              mountPath = local.vault_auth_path
              role      = local.vault_role_name
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

resource "kubernetes_manifest" "grafana_admin_external_secret" {
  depends_on = [kubernetes_manifest.observability_vault_secret_store]

  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "grafana-admin-secret"
      namespace = kubernetes_namespace.observability.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "observability-vault-store"
        kind = "SecretStore"
      }
      target = {
        name           = "grafana-admin-secret"
        creationPolicy = "Owner"
        template = {
          engineVersion = "v2"
          data = {
            "admin-user"     = "admin"
            "admin-password" = "{{ .grafana_admin_password }}"
          }
        }
      }
      data = [{
        secretKey = "grafana_admin_password"
        remoteRef = {
          key      = local.credential_paths["observability"]["frontend"]
          property = "grafana_admin_password"
        }
      }]
    }
  }
}

resource "kubernetes_manifest" "mimir_s3_external_secret" {
  depends_on = [kubernetes_manifest.observability_vault_secret_store]

  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "mimir-s3-creds"
      namespace = kubernetes_namespace.observability.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "observability-vault-store"
        kind = "SecretStore"
      }
      target = {
        name           = "mimir-s3-creds"
        creationPolicy = "Owner"
      }
      data = [
        { secretKey = "MIMIR_BLOCKS_ACCESS_KEY", remoteRef = { key = "${local.s3_credentials_prefix}/mimir-blocks", property = "access_key" } },
        { secretKey = "MIMIR_BLOCKS_SECRET_KEY", remoteRef = { key = "${local.s3_credentials_prefix}/mimir-blocks", property = "secret_key" } },
        { secretKey = "MIMIR_RULER_ACCESS_KEY", remoteRef = { key = "${local.s3_credentials_prefix}/mimir-ruler", property = "access_key" } },
        { secretKey = "MIMIR_RULER_SECRET_KEY", remoteRef = { key = "${local.s3_credentials_prefix}/mimir-ruler", property = "secret_key" } },
        { secretKey = "MIMIR_ALERTMANAGER_ACCESS_KEY", remoteRef = { key = "${local.s3_credentials_prefix}/mimir-alertmanager", property = "access_key" } },
        { secretKey = "MIMIR_ALERTMANAGER_SECRET_KEY", remoteRef = { key = "${local.s3_credentials_prefix}/mimir-alertmanager", property = "secret_key" } },
      ]
    }
  }
}

resource "kubernetes_manifest" "loki_s3_external_secret" {
  depends_on = [kubernetes_manifest.observability_vault_secret_store]

  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "loki-s3-creds"
      namespace = kubernetes_namespace.observability.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "observability-vault-store"
        kind = "SecretStore"
      }
      target = {
        name           = "loki-s3-creds"
        creationPolicy = "Owner"
      }
      data = [
        { secretKey = "LOKI_ACCESS_KEY", remoteRef = { key = "${local.s3_credentials_prefix}/loki-service", property = "access_key" } },
        { secretKey = "LOKI_SECRET_KEY", remoteRef = { key = "${local.s3_credentials_prefix}/loki-service", property = "secret_key" } },
      ]
    }
  }
}
