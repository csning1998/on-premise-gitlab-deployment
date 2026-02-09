
resource "helm_release" "gitlab" {
  name             = "gitlab"
  chart            = "gitlab"
  repository       = "https://charts.gitlab.io/"
  namespace        = kubernetes_namespace.gitlab_ns.metadata[0].name
  version          = var.helm_config.version
  timeout          = var.helm_config.timeout
  create_namespace = true

  depends_on = [
    kubernetes_manifest.gitlab_certificate,
    kubernetes_secret.gitlab_postgres_password,
    kubernetes_secret.gitlab_redis_password,
    kubernetes_secret.gitlab_minio_secrets,
    kubernetes_secret.gitlab_internal_secrets,
    kubernetes_secret.gitlab_ca_bundle
  ]

  values = [
    yamlencode({
      installCertmanager = false

      global = {
        edition = var.gitlab_config.edition
        certificates = {
          customCAs = [
            {
              secret = kubernetes_secret.gitlab_ca_bundle.metadata[0].name
            }
          ]
        }

        # Domain & Ingress
        hosts = {
          # Use regex to remove "gitlab." from the hostname.
          domain     = replace(var.gitlab_config.hostname, "/^gitlab\\./", "")
          externalIP = null
          https      = true
          gitlab     = {}
          ssh        = "~"
        }

        # Trust Engine Integration
        ingress = {
          configureCertmanager = false # use own secret
          class                = var.ingress_config.class_name
          annotations = {
            "cert-manager.io/issuer" = null
          }
          tls = {
            enabled    = true
            secretName = var.ingress_config.tls_secret_name
          }
        }

        # External DB
        psql = {
          password = {
            secret = kubernetes_secret.gitlab_postgres_password.metadata[0].name
            key    = "password"
          }
          host     = var.external_services.postgres.host
          port     = var.external_services.postgres.port
          username = var.external_services.postgres.username
          database = var.external_services.postgres.database

          ssl = var.external_services.postgres.ssl_secret != null ? {
            secret            = var.external_services.postgres.ssl_secret
            clientCertificate = "tls.crt"
            clientKey         = "tls.key"
            serverCA          = "ca.crt"
          } : null
        }

        # External Redis
        redis = {
          password = {
            secret = kubernetes_secret.gitlab_redis_password.metadata[0].name
            key    = "password"
          }
          host   = var.external_services.redis.host
          port   = var.external_services.redis.port
          scheme = "rediss"
        }

        # Object Storage (S3/MinIO)
        minio = { enabled = false }

        appConfig = {
          lfs = {
            bucket = var.external_services.minio.buckets["lfs"].name
            connection = {
              secret = kubernetes_secret.gitlab_minio_secrets["lfs"].metadata[0].name
              key    = "connection"
            }
          }
          artifacts = {
            bucket = var.external_services.minio.buckets["artifacts"].name
            connection = {
              secret = kubernetes_secret.gitlab_minio_secrets["artifacts"].metadata[0].name
              key    = "connection"
            }
          }
          uploads = {
            bucket = var.external_services.minio.buckets["uploads"].name
            connection = {
              secret = kubernetes_secret.gitlab_minio_secrets["uploads"].metadata[0].name
              key    = "connection"
            }
          }
          packages = {
            bucket = var.external_services.minio.buckets["packages"].name
            connection = {
              secret = kubernetes_secret.gitlab_minio_secrets["packages"].metadata[0].name
              key    = "connection"
            }
          }
          backups = {
            bucket    = var.external_services.minio.buckets["backups"].name
            tmpBucket = var.external_services.minio.buckets["tmp"].name
            connection = {
              secret = kubernetes_secret.gitlab_minio_secrets["backups"].metadata[0].name
              key    = "connection"
            }
          }
          terraformState = {
            bucket = var.external_services.minio.buckets["terraform-state"].name
            connection = {
              secret = kubernetes_secret.gitlab_minio_secrets["terraform-state"].metadata[0].name
              key    = "connection"
            }
          }
        }

        shell = {
          authToken = {
            secret = kubernetes_secret.gitlab_internal_secrets["shell-secret"].metadata[0].name,
            key    = "secret"
          }
        }
        gitaly = {
          authToken = {
            secret = kubernetes_secret.gitlab_internal_secrets["gitaly-secret"].metadata[0].name,
            key    = "token"
          }
        }
        rails = {
          secret = {
            secret = kubernetes_secret.gitlab_internal_secrets["rails-secret"].metadata[0].name,
            key    = "secret"
          }
        }
        initialRootPassword = {
          secret = kubernetes_secret.gitlab_internal_secrets["root-password"].metadata[0].name,
          key    = "secret"
        }

        certificates = {
          customCAs = [
            {
              secret = kubernetes_secret.gitlab_ca_bundle.metadata[0].name
            }
          ]
        }
      }

      # Disable Bundled Services
      nginx-ingress = { enabled = false }
      prometheus    = { install = false }
      postgresql    = { install = false }
      redis         = { install = false }
      registry      = { enabled = false }
      gitlab-runner = { install = false }

      # Component Specifics
      gitlab = {
        webservice = {
          minReplicas = 1
          maxReplicas = 2
          deployment = {
            hostAliases = var.external_services.minio.ip != null ? [
              {
                ip        = var.external_services.minio.ip
                hostnames = [var.external_services.minio.hostname]
              }
            ] : []
          }
        }
        sidekiq = {
          minReplicas = 1
          maxReplicas = 2
          deployment = {
            hostAliases = var.external_services.minio.ip != null ? [
              {
                ip        = var.external_services.minio.ip
                hostnames = [var.external_services.minio.hostname]
              }
            ] : []
          }
        }
        toolbox = {
          deployment = {
            hostAliases = var.external_services.minio.ip != null ? [
              {
                ip        = var.external_services.minio.ip
                hostnames = [var.external_services.minio.hostname]
              }
            ] : []
          }
          backups = {
            objectStorage = {
              config = {
                secret = kubernetes_secret.gitlab_minio_secrets["backups"].metadata[0].name
                key    = "connection"
              }
            }
          }
        }
      }
    })
  ]
}
