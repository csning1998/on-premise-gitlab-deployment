
locals {
  ca_volume = [{
    name = "ca-bundle"
    secret = {
      secretName = var.helm_config.ca_bundle_secret_name
    }
  }]

  ca_volume_mount = [{
    name      = "ca-bundle"
    mountPath = "/etc/ssl/certs/custom-ca.crt"
    subPath   = "ca.crt"
    readOnly  = true
  }]

  s3_env_from = [{
    secretRef = { name = var.storage_config.s3_existing_secret_name }
  }]

  s3_extra_args = { "config.expand-env" = "true" }

  # This chart has no working global podAnnotations passthrough; each component's block
  # needs it set individually to be picked up by Alloy's pod-annotation discovery.
  metrics_annotations = {
    "prometheus.io/scrape" = "true"
    "prometheus.io/port"   = "8080"
    "prometheus.io/path"   = "/metrics"
  }
}

resource "helm_release" "mimir" {
  name             = "mimir"
  chart            = "oci://${var.helm_config.image_registry}/${var.helm_config.chart_project}/mimir-distributed"
  version          = var.helm_config.version
  namespace        = var.helm_config.namespace
  create_namespace = false
  timeout          = var.helm_config.timeout

  values = [yamlencode({
    fullnameOverride = "mimir"

    image = {
      repository = "${var.helm_config.image_registry}/${var.helm_config.image_repository}/grafana/mimir"
    }

    kafka = { enabled = false }
    minio = { enabled = false }

    mimir = {
      structuredConfig = {
        multitenancy_enabled = true
        ingest_storage = {
          enabled = false
        }
        ingester = {
          ring = {
            replication_factor = 1
          }
          push_grpc_method_enabled = true
        }
        common = {
          storage = {
            backend = "s3"
            s3 = {
              endpoint = var.storage_config.endpoint
              http = {
                tls_ca_path = "/etc/ssl/certs/custom-ca.crt"
              }
            }
          }
        }
        blocks_storage = {
          s3 = {
            bucket_name       = var.storage_config.blocks_bucket
            access_key_id     = "$${MIMIR_BLOCKS_ACCESS_KEY}"
            secret_access_key = "$${MIMIR_BLOCKS_SECRET_KEY}"
          }
        }
        ruler_storage = {
          s3 = {
            bucket_name       = var.storage_config.ruler_bucket
            access_key_id     = "$${MIMIR_RULER_ACCESS_KEY}"
            secret_access_key = "$${MIMIR_RULER_SECRET_KEY}"
          }
        }
        alertmanager_storage = {
          s3 = {
            bucket_name       = var.storage_config.alertmanager_bucket
            access_key_id     = "$${MIMIR_ALERTMANAGER_ACCESS_KEY}"
            secret_access_key = "$${MIMIR_ALERTMANAGER_SECRET_KEY}"
          }
        }
        # 100000 default: The baseline on the observability tenant is approximately 47k to 52k series
        # (comprising kubelet, node_exporter, and cadvisor metrics). A 50k limit provides insufficient
        # headroom, causing series rejection prior to increasing this value.
        limits = {
          max_global_series_per_user = 100000
        }
      }
    }

    # Per-tenant overrides on top of the limits default above; reloaded automatically, no restart needed.
    runtimeConfig = {
      overrides = {
        gitlab = {
          max_global_series_per_user = 150000
        }
      }
    }

    ingester = {
      replicas = 1
      zoneAwareReplication = {
        enabled = false
      }
      resources = {
        requests = { memory = "256Mi" }
        limits   = { memory = "1Gi" }
      }
      podAnnotations    = local.metrics_annotations
      extraArgs         = local.s3_extra_args
      extraEnvFrom      = local.s3_env_from
      extraVolumes      = local.ca_volume
      extraVolumeMounts = local.ca_volume_mount
    }

    store_gateway = {
      replicas = 1
      zoneAwareReplication = {
        enabled = false
      }
      resources = {
        requests = { memory = "128Mi" }
        limits   = { memory = "512Mi" }
      }
      podAnnotations    = local.metrics_annotations
      extraArgs         = local.s3_extra_args
      extraEnvFrom      = local.s3_env_from
      extraVolumes      = local.ca_volume
      extraVolumeMounts = local.ca_volume_mount
    }

    compactor = {
      replicas = 1
      resources = {
        requests = { memory = "128Mi" }
        limits   = { memory = "512Mi" }
      }
      podAnnotations    = local.metrics_annotations
      extraArgs         = local.s3_extra_args
      extraEnvFrom      = local.s3_env_from
      extraVolumes      = local.ca_volume
      extraVolumeMounts = local.ca_volume_mount
    }

    alertmanager = {
      replicas = 1
      resources = {
        requests = { memory = "32Mi" }
        limits   = { memory = "128Mi" }
      }
      podAnnotations    = local.metrics_annotations
      extraArgs         = local.s3_extra_args
      extraEnvFrom      = local.s3_env_from
      extraVolumes      = local.ca_volume
      extraVolumeMounts = local.ca_volume_mount
    }

    ruler = {
      replicas = 1
      resources = {
        requests = { memory = "64Mi" }
        limits   = { memory = "256Mi" }
      }
      podAnnotations    = local.metrics_annotations
      extraArgs         = local.s3_extra_args
      extraEnvFrom      = local.s3_env_from
      extraVolumes      = local.ca_volume
      extraVolumeMounts = local.ca_volume_mount
    }

    querier = {
      replicas = 1
      resources = {
        requests = { memory = "128Mi" }
        limits   = { memory = "512Mi" }
      }
      podAnnotations    = local.metrics_annotations
      extraArgs         = local.s3_extra_args
      extraEnvFrom      = local.s3_env_from
      extraVolumes      = local.ca_volume
      extraVolumeMounts = local.ca_volume_mount
    }

    distributor = {
      replicas = 1
      resources = {
        requests = { memory = "64Mi" }
        limits   = { memory = "256Mi" }
      }
      podAnnotations = local.metrics_annotations
    }

    query_frontend = {
      replicas = 1
      resources = {
        requests = { memory = "128Mi" }
        limits   = { memory = "256Mi" }
      }
      podAnnotations = local.metrics_annotations
    }

    query_scheduler = {
      replicas = 1
      resources = {
        requests = { memory = "64Mi" }
        limits   = { memory = "128Mi" }
      }
      podAnnotations = local.metrics_annotations
    }

    overrides_exporter = {
      podAnnotations = local.metrics_annotations
    }

    gateway = {
      nginxConfig = {
        resolver = var.helm_config.dns_resolver
      }
    }
  })]
}
