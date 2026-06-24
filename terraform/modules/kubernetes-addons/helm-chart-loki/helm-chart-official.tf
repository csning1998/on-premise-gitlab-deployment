
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
          accessKeyId      = "$${LOKI_ACCESS_KEY}"
          secretAccessKey  = "$${LOKI_SECRET_KEY}"
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
      replicas  = 1
      extraArgs = ["-config.expand-env=true"]
      extraEnvFrom = [{
        secretRef = { name = var.storage_config.s3_existing_secret_name }
      }]
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

    read    = { replicas = 0 }
    write   = { replicas = 0 }
    backend = { replicas = 0 }
    minio   = { enabled = false }

    # chunksCache reduces S3 round-trips for repeated log chunk reads;
    # resultsCache short-circuits re-execution of identical LogQL queries.
    # Both are external Memcached StatefulSets and are disabled here
    # since MinIO runs on the same node (loopback latency),
    # making the cache benefit negligible while each pod claims 1229 Mi of memory requests.
    chunksCache  = { enabled = false }
    resultsCache = { enabled = false }
  })]
}
