
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
      # Multi-tenant: each of the 4 K8s clusters' Alloy writes under its own tenant_id
      # (same boundary as Mimir), isolating log queries and retention per tenant.
      auth_enabled = true

      # Chart default (3) assumes a multi-replica ring; with singleBinary.replicas = 1 below,
      # a replication factor of 3 leaves the ring permanently short of quorum ((3/2)+1 = 2
      # needed, only 1 exists), failing every read/write with "too many unhealthy instances".
      commonConfig = {
        replication_factor = 1
      }

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

      # GitLab's audit_json.log lines carry subcomponent="audit_json" (multiplexed onto
      # webservice/sidekiq stdout alongside production_json/api_json; Alloy's loki.process
      # stage extracts this field into a label), overridden to a longer period since audit
      # trail has more compliance value than general application/pod logs.
      limits_config = {
        retention_period = "${24 * 14}h" # 14d
        retention_stream = [{
          selector = "{subcomponent=\"audit_json\"}"
          priority = 1
          period   = "${24 * 90}h" # 90d
        }]
      }

      compactor = {
        retention_enabled    = true
        delete_request_store = "s3"
      }
    }

    singleBinary = {
      replicas = 1
      # Not annotated by default, so Alloy's pod-annotation discovery would otherwise miss it.
      podAnnotations = {
        "prometheus.io/scrape" = "true"
        "prometheus.io/port"   = "3100"
        "prometheus.io/path"   = "/metrics"
      }
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
