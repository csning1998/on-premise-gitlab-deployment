
# metrics.enabled only opens the /metrics port; it doesn't add scrape annotations, so each component sets them explicitly.
locals {
  harbor_metrics_annotations = {
    "prometheus.io/scrape" = "true"
    "prometheus.io/port"   = "8001"
    "prometheus.io/path"   = "/metrics"
  }
}

# Harbor Helm Release
resource "helm_release" "harbor" {
  name             = "harbor"
  chart            = "oci://${var.helm_config.image_registry}/${var.helm_config.chart_project}/harbor"
  version          = var.helm_config.version
  namespace        = var.helm_config.namespace
  timeout          = var.helm_config.timeout
  create_namespace = true

  depends_on = [
    kubernetes_secret.harbor_ca_bundle
  ]

  values = [
    yamlencode({
      harborAdminPassword = var.harbor_config.admin_password
      secretKey           = var.harbor_config.secret_key

      expose = {
        type = "ingress"
        tls = {
          enabled    = true
          certSource = "secret"
          secret = {
            secretName = var.ingress_config.tls_secret_name
          }
        }
        ingress = {
          hosts = {
            core   = var.harbor_config.hostname
            notary = "${var.harbor_config.notary_prefix}.${var.harbor_config.hostname}"
          }
          className = var.ingress_config.class_name
          annotations = {
            "nginx.ingress.kubernetes.io/proxy-body-size" = "0"
            (var.ingress_config.issuer_kind == "ClusterIssuer"
              ? "cert-manager.io/cluster-issuer"
              : "cert-manager.io/issuer"
            )                                           = var.ingress_config.issuer_name
            "cert-manager.io/common-name"               = var.harbor_config.hostname
            "cert-manager.io/subject-alternative-names" = join(",", var.harbor_config.dns_sans)
            "cert-manager.io/duration"                  = var.certificate_config.duration
            "cert-manager.io/renew-before"              = var.certificate_config.renew_before
          }
        }
      }

      externalURL        = "https://${var.harbor_config.hostname}"
      caBundleSecretName = var.ca_bundle.secret_name

      persistence = {
        enabled = true
        imageChartStorage = {
          type            = "s3"
          disableredirect = true
          s3 = {
            region         = var.external_services.s3.region
            bucket         = var.external_services.s3.bucket
            accesskey      = var.external_services.s3.access_key
            secretkey      = var.external_services.s3.secret_key
            regionendpoint = var.external_services.s3.endpoint
            forcePathStyle = true
            secure         = true
            v4auth         = true
            encrypt        = false
          }
        }
      }

      database = {
        type = "external"
        external = {
          host     = var.external_services.postgres.host
          port     = var.external_services.postgres.port
          username = "harbor"
          password = var.external_services.postgres.password
          sslmode  = "verify-ca"
        }
      }

      redis = {
        type = "external"
        external = {
          addr     = var.external_services.redis.host
          password = var.external_services.redis.password
          tlsOptions = {
            enable = true
          }
        }
      }

      metrics    = { enabled = true }
      core       = { podAnnotations = local.harbor_metrics_annotations }
      registry   = { podAnnotations = local.harbor_metrics_annotations }
      jobservice = { podAnnotations = local.harbor_metrics_annotations }
      exporter   = { podAnnotations = local.harbor_metrics_annotations }
    }),

    yamlencode(var.helm_values_override)
  ]
}
