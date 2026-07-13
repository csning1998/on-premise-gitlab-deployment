
resource "kubernetes_namespace" "harbor" {
  metadata {
    name = "harbor"
  }
}

resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
  }
}

# For Harbor core secret key
resource "random_password" "harbor_core_secret_key" {
  length  = 32
  special = true
  upper   = true
}

module "alloy_client_cert" {
  source     = "../../modules/kubernetes-addons/platform-mtls-certificate"
  depends_on = [kubernetes_namespace.observability]

  name         = "alloy-client-cert"
  namespace    = kubernetes_namespace.observability.metadata[0].name
  common_name  = local.mimir_fqdn
  dns_sans     = []
  issuer_name  = local.issuer_name
  issuer_kind  = local.issuer_kind
  duration     = local.state.vault_pki.pki_configuration.lease_durations.default
  renew_before = local.state.vault_pki.pki_configuration.lease_durations.agent
}

module "alloy" {
  source     = "../../modules/kubernetes-addons/helm-chart-alloy"
  depends_on = [module.alloy_client_cert, kubernetes_namespace.observability]

  helm_config = {
    version          = var.alloy_version
    namespace        = kubernetes_namespace.observability.metadata[0].name
    timeout          = 300
    image_registry   = local.harbor_registry
    chart_project    = local.helm_chart_project
    image_repository = local.harbor_docker_proxy
  }

  alloy_config = {
    remote_write_url      = local.mimir_remote_write_url
    loki_push_url         = local.loki_push_url
    cluster_label         = local.mimir_tenant_id
    tenant_id             = local.mimir_tenant_id
    mtls_cert_secret_name = module.alloy_client_cert.secret_name
  }

  vm_static_targets = concat(
    [
      {
        address = "${local.postgres_vip}:${local.postgres_exporter_port}",
        job     = "harbor-postgres-exporter",
        labels  = { component = "postgres" }
      },
      {
        address = "${local.redis_vip}:${local.redis_exporter_port}",
        job     = "harbor-redis-exporter",
        labels  = { component = "redis" }
      },
    ],
    [for ip in local.etcd_ips : {
      address = "${ip}:${local.etcd_client_port}"
      job     = "harbor-etcd"
      labels  = { component = "etcd", instance = ip }
    }],
    flatten([
      for component, ips in local.node_exporter_ip_groups : [
        for ip in ips : {
          address = "${ip}:${local.node_exporter_port}"
          job     = "harbor-node"
          labels  = { component = component, instance = ip }
        }
      ]
    ])
  )

  minio_scrape_targets = [{
    address = "${local.minio_vip}:${local.minio_port}"
    job     = "harbor-minio"
    labels  = { component = "minio" }
  }]

  blackbox_targets = local.blackbox_external_targets
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

module "harbor_core" {
  source     = "../../modules/kubernetes-addons/helm-chart-harbor"
  depends_on = [kubernetes_namespace.harbor]

  ca_bundle = local.ca_bundle_config

  helm_config = {
    version        = var.harbor_helm_config.version
    namespace      = var.harbor_helm_config.namespace
    timeout        = 600
    image_registry = local.harbor_registry
    chart_project  = local.helm_chart_project
  }

  certificate_config = {
    duration     = local.state.vault_pki.pki_configuration.lease_durations.default
    renew_before = local.state.vault_pki.pki_configuration.lease_durations.agent
  }

  harbor_config = {
    hostname       = local.harbor_frontend_fqdn
    admin_password = local.harbor_admin_password
    notary_prefix  = var.harbor_helm_config.notary_prefix
    secret_key     = random_password.harbor_core_secret_key.result
    dns_sans       = local.state.vault_pki.global_pki_map["harbor-frontend"].dns_san
  }

  helm_values_override = local.harbor_helm_overrides

  ingress_config = {
    class_name      = var.harbor_helm_config.ingress_class
    tls_secret_name = var.harbor_helm_config.tls_secret_name
    issuer_name     = local.issuer_name
    issuer_kind     = local.issuer_kind
  }

  external_services = {
    postgres = {
      host     = local.postgres_fqdn
      password = local.harbor_db.password
      port     = local.pg_port
    }
    redis = {
      host     = local.redis_fqdn
      password = local.redis_password
    }
    s3 = {
      bucket     = var.object_storage_config.bucket_name
      region     = var.object_storage_config.region
      access_key = local.minio_access_key
      secret_key = local.minio_secret_key
      endpoint   = "https://${local.minio_fqdn}:${local.minio_port}"
    }
  }
}
