
resource "helm_release" "loki" {
  name             = "loki"
  chart            = "oci://${var.helm_config.image_registry}/${var.helm_config.chart_project}/loki"
  version          = var.helm_config.version
  namespace        = var.helm_config.namespace
  create_namespace = false
  timeout          = var.helm_config.timeout

  values = [yamlencode({
    fullnameOverride = "loki"
    deploymentMode   = "SingleBinary"

    loki = {
      auth_enabled = false

      image = {
        registry   = var.helm_config.image_registry
        repository = "${var.helm_config.image_repository}/grafana/loki"
      }

      storage = {
        type = "s3"
        bucketNames = {
          chunks = var.storage_config.chunks_bucket
          ruler  = var.storage_config.ruler_bucket
          admin  = var.storage_config.admin_bucket
        }
        s3 = {
          endpoint         = var.storage_config.endpoint
          region           = "us-east-1"
          accessKeyId      = var.storage_config.access_key
          secretAccessKey  = var.storage_config.secret_key
          s3ForcePathStyle = true
          http_config = {
            ca_file = "/etc/ssl/certs/custom-ca.crt"
          }
        }
      }

      schemaConfig = {
        configs = [{
          from         = "2026-01-01"
          store        = "tsdb"
          object_store = "s3"
          schema       = "v13"
          index = {
            prefix = "index_"
            period = "24h"
          }
        }]
      }
    }

    singleBinary = {
      replicas = 1
      extraVolumes = [{
        name = "ca-bundle"
        secret = {
          secretName = var.helm_config.ca_bundle_secret_name
        }
      }]
      extraVolumeMounts = [{
        name      = "ca-bundle"
        mountPath = "/etc/ssl/certs/custom-ca.crt"
        subPath   = "ca.crt"
        readOnly  = true
      }]
    }

    read = {
      replicas = 0
    }

    write = {
      replicas = 0
    }

    backend = {
      replicas = 0
    }

    minio = {
      enabled = false
    }

    chunksCache = {
      allocatedMemory = 1024
    }

    gateway = {
      nginxConfig = {
        resolver = var.helm_config.dns_resolver
      }
    }

    sidecar = {
      rules = {
        enabled = false
      }
    }

  })]
}
