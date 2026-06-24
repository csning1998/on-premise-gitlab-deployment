
resource "kubernetes_namespace" "observability" {
  metadata {
    name = var.observability_stack_config.namespace
  }
}

module "mimir" {
  source = "../../modules/kubernetes-addons/helm-chart-mimir"
  depends_on = [
    kubernetes_namespace.observability,
    kubernetes_secret.ca_bundle,
    kubernetes_manifest.mimir_s3_external_secret
  ]

  helm_config = {
    version               = var.observability_stack_config.mimir_version
    namespace             = var.observability_stack_config.namespace
    timeout               = 600
    image_registry        = local.harbor_registry
    chart_project         = local.helm_chart_project
    image_repository      = local.harbor_docker_proxy
    dns_resolver          = data.kubernetes_service.kube_dns.spec[0].cluster_ip
    ca_bundle_secret_name = local.ca_bundle_config.secret_name
  }

  storage_config = {
    endpoint                = "${local.minio_fqdn}:${local.minio_port}"
    s3_existing_secret_name = "mimir-s3-creds"
    blocks_bucket           = local.state.minio_provision.minio_function_map["mimir-blocks"]
    ruler_bucket            = local.state.minio_provision.minio_function_map["mimir-ruler"]
    alertmanager_bucket     = local.state.minio_provision.minio_function_map["mimir-alertmanager"]
  }
}

module "loki" {
  source = "../../modules/kubernetes-addons/helm-chart-loki"
  depends_on = [
    kubernetes_namespace.observability,
    kubernetes_secret.ca_bundle,
    kubernetes_manifest.loki_s3_external_secret
  ]

  helm_config = {
    version               = var.observability_stack_config.loki_version
    namespace             = var.observability_stack_config.namespace
    timeout               = 600
    image_registry        = local.harbor_registry
    chart_project         = local.helm_chart_project
    image_repository      = local.harbor_docker_proxy
    dns_resolver          = data.kubernetes_service.kube_dns.spec[0].cluster_ip
    ca_bundle_secret_name = local.ca_bundle_config.secret_name
  }

  storage_config = {
    endpoint                = "https://${local.minio_fqdn}:${local.minio_port}"
    s3_existing_secret_name = "loki-s3-creds"
    chunks_bucket           = local.state.minio_provision.minio_function_map["loki-chunks"]
    ruler_bucket            = local.state.minio_provision.minio_function_map["loki-ruler"]
    admin_bucket            = local.state.minio_provision.minio_function_map["loki-admin"]
  }
}

module "grafana" {
  source = "../../modules/kubernetes-addons/helm-chart-grafana"
  depends_on = [
    module.mimir,
    module.loki,
    kubernetes_namespace.observability,
    kubernetes_manifest.grafana_admin_external_secret
  ]

  helm_config = {
    version          = var.observability_stack_config.grafana_version
    namespace        = var.observability_stack_config.namespace
    timeout          = 600
    image_registry   = local.harbor_registry
    chart_project    = local.helm_chart_project
    image_repository = local.harbor_docker_proxy
  }

  grafana_config = {
    fqdn                       = local.grafana_fqdn
    admin_existing_secret_name = "grafana-admin-secret"
    dns_sans                   = local.state.metadata.global_pki_map["observability-frontend"].dns_san
  }

  ingress_config = {
    class_name      = var.ingress_class_name
    tls_secret_name = "grafana-ingress-cert"
    issuer_name     = var.trust_engine_config.issuer_name
    issuer_kind     = var.trust_engine_config.issuer_kind
  }

  certificate_config = {
    duration     = local.state.vault_pki.pki_configuration.lease_durations.default
    renew_before = local.state.vault_pki.pki_configuration.lease_durations.agent
  }

  datasources_config = {
    mimir_url = module.mimir.query_url
    loki_url  = module.loki.service_url
  }

  ca_bundle = { secret_name = local.ca_bundle_config.secret_name }
}
