
resource "helm_release" "alloy" {
  name             = "alloy"
  chart            = "oci://${var.helm_config.image_registry}/${var.helm_config.chart_project}/alloy"
  version          = var.helm_config.version
  timeout          = var.helm_config.timeout
  namespace        = var.helm_config.namespace
  create_namespace = false

  values = [yamlencode({
    alloy = {
      configMap = {
        content = templatefile("${path.module}/templates/river_config.tftpl", {
          remote_write_url         = var.alloy_config.remote_write_url
          loki_push_url            = var.alloy_config.loki_push_url
          cluster_label            = var.alloy_config.cluster_label
          tenant_id                = var.alloy_config.tenant_id
          mtls_enabled             = var.alloy_config.mtls_cert_secret_name != null
          guest_scrape_targets     = var.guest_scrape_targets
          workhorse_scrape_enabled = var.workhorse_scrape_enabled
          vault_metrics_address    = var.vault_metrics_address
          vault_metrics_token_file = var.vault_metrics_token_secret_name != null ? "/etc/alloy/vault-token/token" : null
          minio_scrape_targets     = var.minio_scrape_targets
          minio_metrics_token_file = var.minio_metrics_token_secret_name != null ? "/etc/alloy/minio-token/token" : null
          keycloak_metrics_address = var.keycloak_metrics_address
          blackbox_targets         = var.blackbox_targets
        })
      }
      image = {
        registry   = var.helm_config.image_registry
        repository = "${var.helm_config.image_repository}/grafana/alloy"
      }
      clustering = {
        enabled = false
      }
      mounts = {
        extra = concat(
          var.alloy_config.mtls_cert_secret_name != null ? [
            { name = "alloy-mtls-cert", mountPath = "/etc/alloy/mtls", readOnly = true }
          ] : [],
          var.alloy_config.ca_bundle_secret_name != null ? [
            { name = "alloy-ca-bundle", mountPath = "/etc/alloy/ca-bundle", readOnly = true }
          ] : [],
          var.vault_metrics_token_secret_name != null ? [
            { name = "alloy-vault-metrics-token", mountPath = "/etc/alloy/vault-token", readOnly = true }
          ] : [],
          var.minio_metrics_token_secret_name != null ? [
            { name = "alloy-minio-metrics-token", mountPath = "/etc/alloy/minio-token", readOnly = true }
          ] : []
        )
      }
    }
    controller = {
      type     = "deployment"
      replicas = 1
      podAnnotations = {
        "prometheus.io/scrape" = "true"
        "prometheus.io/port"   = "12345"
        "prometheus.io/path"   = "/metrics"
      }
      volumes = {
        extra = concat(
          var.alloy_config.mtls_cert_secret_name != null ? [
            { name = "alloy-mtls-cert", secret = { secretName = var.alloy_config.mtls_cert_secret_name } }
          ] : [],
          var.alloy_config.ca_bundle_secret_name != null ? [
            { name = "alloy-ca-bundle", secret = { secretName = var.alloy_config.ca_bundle_secret_name } }
          ] : [],
          var.vault_metrics_token_secret_name != null ? [
            { name = "alloy-vault-metrics-token", secret = { secretName = var.vault_metrics_token_secret_name } }
          ] : [],
          var.minio_metrics_token_secret_name != null ? [
            { name = "alloy-minio-metrics-token", secret = { secretName = var.minio_metrics_token_secret_name } }
          ] : []
        )
      }
    }
    serviceAccount = { create = true }
    rbac           = { create = true }
  })]

  lifecycle {
    precondition {
      condition     = length(var.minio_scrape_targets) == 0 || var.minio_metrics_token_secret_name != null
      error_message = "minio_metrics_token_secret_name must be set whenever minio_scrape_targets is non-empty; an unauthenticated scrape against MinIO's JWT-protected endpoint returns HTTP 401 and records up=0."
    }
  }
}
