
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

module "alloy" {
  source     = "../../modules/kubernetes-addons/helm-chart-alloy"
  depends_on = [module.mimir, kubernetes_namespace.observability]

  helm_config = {
    version          = var.observability_stack_config.alloy_version
    namespace        = var.observability_stack_config.namespace
    timeout          = 300
    image_registry   = local.harbor_registry
    chart_project    = local.helm_chart_project
    image_repository = local.harbor_docker_proxy
  }

  alloy_config = {
    remote_write_url      = module.mimir.remote_write_url
    cluster_label         = var.observability_stack_config.cluster_name
    tenant_id             = var.observability_stack_config.cluster_name
    ca_bundle_secret_name = local.ca_bundle_config.secret_name
  }

  vm_static_targets = concat(
    [
      for ip in local.central_lb_ips : {
        address = "${ip}:${local.port_haproxy_stats}"
        job     = "central-lb-haproxy"
        labels  = { component = "haproxy", instance = ip }
      }
    ],
    [{
      address = local.harbor_bootstrapper_metrics_address
      job     = "harbor-bootstrapper"
      labels  = { component = "harbor" }
    }],
    flatten([
      for component, ips in local.node_exporter_ip_groups : [
        for ip in ips : {
          address = "${ip}:${local.node_exporter_port}"
          job     = "observability-node"
          labels  = { component = component, instance = ip }
        }
      ]
    ])
  )

  vault_metrics_address    = local.vault_metrics_address
  keycloak_metrics_address = local.keycloak_metrics_address
  blackbox_targets         = local.blackbox_targets
}

module "kube_state_metrics" {
  source     = "../../modules/kubernetes-addons/helm-chart-kube-state-metrics"
  depends_on = [kubernetes_namespace.observability]

  helm_config = {
    version          = var.kube_state_metrics_version
    namespace        = kubernetes_namespace.observability.metadata[0].name
    timeout          = 300
    image_registry   = local.harbor_registry
    chart_project    = local.helm_chart_project
    image_repository = local.harbor_k8s_proxy
  }
}

module "alloy_client_cert" {
  source     = "../../modules/kubernetes-addons/platform-mtls-certificate"
  depends_on = [kubernetes_namespace.observability]

  name         = "alloy-client-cert"
  namespace    = var.observability_stack_config.namespace
  common_name  = local.grafana_fqdn
  dns_sans     = []
  issuer_name  = local.issuer_name
  issuer_kind  = local.issuer_kind
  duration     = local.state.vault_pki.pki_configuration.lease_durations.default
  renew_before = local.state.vault_pki.pki_configuration.lease_durations.agent
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
    dns_sans                   = local.state.vault_pki.global_pki_map["observability-frontend"].dns_san
  }

  ingress_config = {
    class_name      = var.ingress_class_name
    tls_secret_name = "grafana-ingress-cert"
    issuer_name     = local.issuer_name
    issuer_kind     = local.issuer_kind
  }

  certificate_config = {
    duration     = local.state.vault_pki.pki_configuration.lease_durations.default
    renew_before = local.state.vault_pki.pki_configuration.lease_durations.agent
  }

  datasources_config = {
    loki_url        = module.loki.service_url
    mimir_url       = module.mimir.query_url
    mimir_tenant_id = var.observability_stack_config.cluster_name
  }

  ca_bundle = { secret_name = local.ca_bundle_config.secret_name }
}
