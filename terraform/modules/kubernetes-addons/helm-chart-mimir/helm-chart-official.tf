
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

    kafka = {
      enabled = false
    }

    minio = {
      enabled = false
    }

    mimir = {
      structuredConfig = {
        ingest_storage = {
          enabled = false
        }
        ingester = {
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
            access_key_id     = var.storage_config.blocks_access_key
            secret_access_key = var.storage_config.blocks_secret_key
          }
        }
        ruler_storage = {
          s3 = {
            bucket_name       = var.storage_config.ruler_bucket
            access_key_id     = var.storage_config.ruler_access_key
            secret_access_key = var.storage_config.ruler_secret_key
          }
        }
        alertmanager_storage = {
          s3 = {
            bucket_name       = var.storage_config.alertmanager_bucket
            access_key_id     = var.storage_config.alertmanager_access_key
            secret_access_key = var.storage_config.alertmanager_secret_key
          }
        }
      }
    }

    ingester = {
      replicas = 1
      zoneAwareReplication = {
        enabled = false
      }
      extraVolumes      = local.ca_volume
      extraVolumeMounts = local.ca_volume_mount
    }

    store_gateway = {
      replicas = 1
      zoneAwareReplication = {
        enabled = false
      }
      extraVolumes      = local.ca_volume
      extraVolumeMounts = local.ca_volume_mount
    }

    compactor = {
      replicas          = 1
      extraVolumes      = local.ca_volume
      extraVolumeMounts = local.ca_volume_mount
    }

    alertmanager = {
      replicas          = 1
      extraVolumes      = local.ca_volume
      extraVolumeMounts = local.ca_volume_mount
    }

    ruler = {
      replicas          = 1
      extraVolumes      = local.ca_volume
      extraVolumeMounts = local.ca_volume_mount
    }

    querier = {
      replicas          = 1
      extraVolumes      = local.ca_volume
      extraVolumeMounts = local.ca_volume_mount
    }

    distributor = {
      replicas = 1
    }

    query_frontend = {
      replicas = 1
    }

    query_scheduler = {
      replicas = 1
    }

    gateway = {
      nginxConfig = {
        resolver = var.helm_config.dns_resolver
      }
    }
  })]
}
