
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
          server   = local.vault_endpoint
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

resource "kubernetes_manifest" "alloy_vault_metrics_token_external_secret" {
  depends_on = [kubernetes_manifest.observability_vault_secret_store]

  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "alloy-vault-metrics-token"
      namespace = kubernetes_namespace.observability.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "observability-vault-store"
        kind = "SecretStore"
      }
      target = {
        name           = "alloy-vault-metrics-token"
        creationPolicy = "Owner"
      }
      data = [{
        secretKey = "token"
        remoteRef = {
          key      = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/observability/app/vault_metrics_token"
          property = "token"
        }
      }]
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
      namespace = kubernetes_namespace.observability.metadata[0].name
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
          key      = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/observability/app/minio_prometheus"
          property = "bearer_token"
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

resource "kubernetes_manifest" "mimir_gateway_network_policy" {
  depends_on = [kubernetes_namespace.observability]

  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "NetworkPolicy"
    metadata = {
      name      = "mimir-gateway-ingress"
      namespace = kubernetes_namespace.observability.metadata[0].name
    }
    spec = {
      podSelector = {
        matchLabels = {
          "app.kubernetes.io/name"      = "mimir"
          "app.kubernetes.io/component" = "gateway"
        }
      }
      policyTypes = ["Ingress"]
      ingress = [{
        from = [
          {
            namespaceSelector = { matchLabels = { "kubernetes.io/metadata.name" = "observability" } }
            podSelector       = { matchLabels = { "app.kubernetes.io/name" = "alloy" } }
          },
          {
            namespaceSelector = { matchLabels = { "kubernetes.io/metadata.name" = "observability" } }
            podSelector       = { matchLabels = { "app.kubernetes.io/name" = "grafana" } }
          },
          {
            namespaceSelector = { matchLabels = { "kubernetes.io/metadata.name" = "ingress-system" } }
          }
        ]
        ports = [{ protocol = "TCP", port = 8080 }]
      }]
    }
  }
}

resource "kubernetes_manifest" "mimir_ingress" {
  depends_on = [
    module.mimir,
    kubernetes_secret.ca_bundle,
  ]

  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "mimir-gateway"
      namespace = kubernetes_namespace.observability.metadata[0].name
      annotations = merge(
        local.issuer_kind == "ClusterIssuer" ? {
          "cert-manager.io/cluster-issuer" = local.issuer_name
          } : {
          "cert-manager.io/issuer" = local.issuer_name
        },
        {
          "cert-manager.io/common-name"                        = local.mimir_fqdn
          "cert-manager.io/subject-alternative-names"          = local.mimir_fqdn
          "cert-manager.io/duration"                           = local.state.vault_pki.pki_configuration.lease_durations.default
          "cert-manager.io/renew-before"                       = local.state.vault_pki.pki_configuration.lease_durations.agent
          "nginx.ingress.kubernetes.io/auth-tls-secret"        = "${kubernetes_namespace.observability.metadata[0].name}/${local.ca_bundle_config.secret_name}"
          "nginx.ingress.kubernetes.io/auth-tls-verify-client" = "on"
          "nginx.ingress.kubernetes.io/auth-tls-verify-depth"  = "1"
          "nginx.ingress.kubernetes.io/proxy-body-size"        = "16m"
        }
      )
    }
    spec = {
      ingressClassName = var.ingress_class_name
      tls = [{
        secretName = "mimir-ingress-cert"
        hosts      = [local.mimir_fqdn]
      }]
      rules = [{
        host = local.mimir_fqdn
        http = {
          paths = [{
            path     = "/"
            pathType = "Prefix"
            backend = {
              service = {
                name = "mimir-gateway"
                port = { number = 8080 }
              }
            }
          }]
        }
      }]
    }
  }
}

resource "kubernetes_manifest" "loki_gateway_network_policy" {
  depends_on = [kubernetes_namespace.observability]

  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "NetworkPolicy"
    metadata = {
      name      = "loki-gateway-ingress"
      namespace = kubernetes_namespace.observability.metadata[0].name
    }
    spec = {
      podSelector = {
        matchLabels = {
          "app.kubernetes.io/name"      = "loki"
          "app.kubernetes.io/component" = "gateway"
        }
      }
      policyTypes = ["Ingress"]
      ingress = [{
        from = [
          {
            namespaceSelector = { matchLabels = { "kubernetes.io/metadata.name" = "observability" } }
            podSelector       = { matchLabels = { "app.kubernetes.io/name" = "alloy" } }
          },
          {
            namespaceSelector = { matchLabels = { "kubernetes.io/metadata.name" = "observability" } }
            podSelector       = { matchLabels = { "app.kubernetes.io/name" = "grafana" } }
          },
          {
            namespaceSelector = { matchLabels = { "kubernetes.io/metadata.name" = "ingress-system" } }
            podSelector       = { matchLabels = { "app.kubernetes.io/name" = "ingress-nginx" } }
          }
        ]
        ports = [{ protocol = "TCP", port = 80 }]
      }]
    }
  }
}

resource "kubernetes_manifest" "loki_ingress" {
  depends_on = [
    module.loki,
    kubernetes_secret.ca_bundle,
  ]

  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "loki-gateway"
      namespace = kubernetes_namespace.observability.metadata[0].name
      annotations = merge(
        local.issuer_kind == "ClusterIssuer" ? {
          "cert-manager.io/cluster-issuer" = local.issuer_name
          } : {
          "cert-manager.io/issuer" = local.issuer_name
        },
        {
          "cert-manager.io/common-name"                        = local.loki_fqdn
          "cert-manager.io/subject-alternative-names"          = local.loki_fqdn
          "cert-manager.io/duration"                           = local.state.vault_pki.pki_configuration.lease_durations.default
          "cert-manager.io/renew-before"                       = local.state.vault_pki.pki_configuration.lease_durations.agent
          "nginx.ingress.kubernetes.io/auth-tls-secret"        = "${kubernetes_namespace.observability.metadata[0].name}/${local.ca_bundle_config.secret_name}"
          "nginx.ingress.kubernetes.io/auth-tls-verify-client" = "on"
          "nginx.ingress.kubernetes.io/auth-tls-verify-depth"  = "1"
          "nginx.ingress.kubernetes.io/proxy-body-size"        = "16m"
        }
      )
    }
    spec = {
      ingressClassName = var.ingress_class_name
      tls = [{
        secretName = "loki-ingress-cert"
        hosts      = [local.loki_fqdn]
      }]
      rules = [{
        host = local.loki_fqdn
        http = {
          paths = [{
            path     = "/"
            pathType = "Prefix"
            backend = {
              service = {
                name = "loki-gateway"
                port = { number = 80 }
              }
            }
          }]
        }
      }]
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
