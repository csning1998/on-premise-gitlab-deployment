
# Harbor Helm Release
resource "helm_release" "harbor" {
  name             = "harbor"
  repository       = "https://helm.goharbor.io"
  chart            = "harbor"
  version          = var.helm_config.version
  namespace        = var.helm_config.namespace
  timeout          = var.helm_config.timeout
  create_namespace = true

  depends_on = [
    kubernetes_manifest.harbor_certificate
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
    })
  ]
}
