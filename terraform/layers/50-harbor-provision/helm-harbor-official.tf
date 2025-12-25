
/**
 * Given the changes announced in bitnami/containers#83267, most of the new and hardened image versions 
 * require a Bitnami Secure Images subscription such that the official Harbor Helm Chart is used instead.
 */

# Harbor Helm Chart: https://github.com/goharbor/harbor-helm/blob/main/values.yaml
resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  version    = "1.18.0"
  namespace  = "harbor"
  timeout    = 600

  depends_on = [
    kubernetes_manifest.harbor_certificate,
    kubernetes_secret.harbor_ca_bundle
  ]

  values = [
    yamlencode({
      harborAdminPassword = data.vault_generic_secret.harbor_vars.data["harbor_admin_password"]

      expose = {
        type = "ingress"
        tls = {
          enabled = true
          # Specify Secret, otherwise Harbor will issue an invalid certificate
          certSource = "secret"
          secret = {
            secretName = "harbor-ingress-cert"
          }
        }
        ingress = {
          hosts = {
            core   = var.harbor_hostname
            notary = "notary.${var.harbor_hostname}"
          }
          className = "nginx"
          annotations = {
            "cert-manager.io/cluster-issuer"              = "vault-issuer"
            "nginx.ingress.kubernetes.io/proxy-body-size" = "0"
          }
        }
      }

      externalURL = "https://${var.harbor_hostname}"
      # Inject CA Bundle Secret, let Harbor trust MinIO and Postgres signed certificates
      caBundleSecretName = "harbor-ca-bundle"

      persistence = {
        enabled = true
        imageChartStorage = {
          type            = "s3"
          disableredirect = true
          s3 = {
            region    = "us-east-1"
            bucket    = "harbor-registry"
            accesskey = data.vault_generic_secret.s3_credentials.data["access_key"]
            secretkey = data.vault_generic_secret.s3_credentials.data["secret_key"]
            # MinIO supports TLS (not support mTLS), thus use https and port must correspond.
            regionendpoint = "https://minio.iac.local:9000"
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
          host     = "postgres.iac.local"
          port     = "5000"
          username = "harbor"
          password = data.vault_generic_secret.harbor_vars.data["harbor_pg_db_password"]
          sslmode  = "verify-ca"
        }
      }

      # Set `enable_tls = false` to disable TLS for Redis in `terraform/layers/20-harbor-redis/main.tf`
      redis = {
        type = "external"
        external = {
          addr     = "redis.iac.local:6379"
          password = data.vault_generic_secret.db_vars.data["redis_requirepass"]
        }
      }
    })
  ]
}
