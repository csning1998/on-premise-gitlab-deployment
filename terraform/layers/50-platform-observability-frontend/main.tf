
module "felix_config" {
  source = "../../modules/kubernetes-addons/calico-felix-config"
}

module "platform_trust_engine" {
  source = "../../modules/kubernetes-addons/platform-trust-engine"
  providers = {
    vault = vault.production
  }

  api_server_connection = {
    host    = local.api_endpoint
    ca_cert = local.cluster_ca
  }

  vault_config = {
    address   = local.vault_address
    ca_cert   = local.vault_ca_cert
    auth_path = local.vault_auth_path
  }

  issuer_config = {
    name            = var.trust_engine_config.issuer_name
    issue_path      = "sign"
    vault_role_name = local.vault_role_name
    pki_mount_path  = local.vault_pki_path
  }

  reviewer_service_account = {
    name      = "vault-reviewer"
    namespace = "default"
  }

  helm_config = {
    install          = true
    version          = var.cert_manager_config.version
    namespace        = var.cert_manager_config.namespace
    create_namespace = true
    image_registry   = local.harbor_registry
    image_repository = "${local.harbor_quay_proxy}/jetstack"
    chart_project    = local.helm_chart_project
  }
}

module "ingress_controller" {
  source = "../../modules/kubernetes-addons/microk8s-ingress"

  ingress_vip        = local.observability_vip
  ingress_class_name = "nginx"
  image_registry     = local.harbor_registry
  chart_project      = local.helm_chart_project
}

module "coredns_config" {
  source = "../../modules/kubernetes-addons/coredns-config"

  hosts = local.dns_hosts
}

module "reloader" {
  source            = "../../modules/kubernetes-addons/reloader"
  harbor_oci_config = local.reloader_oci_config
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

module "mimir" {
  source = "../../modules/kubernetes-addons/helm-chart-mimir"
  depends_on = [
    module.platform_trust_engine,
    module.coredns_config,
    kubernetes_namespace.monitoring,
    kubernetes_secret.ca_bundle
  ]

  helm_config = {
    version               = var.monitoring_stack_config.mimir_version
    namespace             = var.monitoring_stack_config.namespace
    timeout               = 600
    image_registry        = local.harbor_registry
    chart_project         = local.helm_chart_project
    image_repository      = local.harbor_docker_proxy
    dns_resolver          = data.kubernetes_service.kube_dns.spec[0].cluster_ip
    ca_bundle_secret_name = local.ca_bundle_config.secret_name
  }

  storage_config = {
    endpoint                = "${local.minio_fqdn}:${local.minio_port}"
    blocks_access_key       = local.mimir_blocks_access_key
    blocks_secret_key       = local.mimir_blocks_secret_key
    ruler_access_key        = local.mimir_ruler_access_key
    ruler_secret_key        = local.mimir_ruler_secret_key
    alertmanager_access_key = local.mimir_alertmanager_access_key
    alertmanager_secret_key = local.mimir_alertmanager_secret_key
    blocks_bucket           = local.state.minio_provision.minio_function_map["mimir-blocks"]
    ruler_bucket            = local.state.minio_provision.minio_function_map["mimir-ruler"]
    alertmanager_bucket     = local.state.minio_provision.minio_function_map["mimir-alertmanager"]
  }
}

module "loki" {
  source = "../../modules/kubernetes-addons/helm-chart-loki"
  depends_on = [
    module.platform_trust_engine,
    module.coredns_config,
    kubernetes_namespace.monitoring,
    kubernetes_secret.ca_bundle
  ]

  helm_config = {
    version               = var.monitoring_stack_config.loki_version
    namespace             = var.monitoring_stack_config.namespace
    timeout               = 600
    image_registry        = local.harbor_registry
    chart_project         = local.helm_chart_project
    image_repository      = local.harbor_docker_proxy
    dns_resolver          = data.kubernetes_service.kube_dns.spec[0].cluster_ip
    ca_bundle_secret_name = local.ca_bundle_config.secret_name
  }

  storage_config = {
    endpoint      = "https://${local.minio_fqdn}:${local.minio_port}"
    access_key    = local.minio_access_key
    secret_key    = local.minio_secret_key
    chunks_bucket = local.state.minio_provision.minio_function_map["loki-chunks"]
    ruler_bucket  = local.state.minio_provision.minio_function_map["loki-ruler"]
    admin_bucket  = local.state.minio_provision.minio_function_map["loki-admin"]
  }
}

module "grafana" {
  source = "../../modules/kubernetes-addons/helm-chart-grafana"
  depends_on = [
    module.platform_trust_engine,
    module.ingress_controller,
    module.coredns_config,
    module.reloader,
    module.mimir,
    module.loki,
    kubernetes_namespace.monitoring
  ]

  helm_config = {
    version          = var.monitoring_stack_config.grafana_version
    namespace        = var.monitoring_stack_config.namespace
    timeout          = 600
    image_registry   = local.harbor_registry
    chart_project    = local.helm_chart_project
    image_repository = local.harbor_docker_proxy
  }

  grafana_config = {
    fqdn           = local.grafana_fqdn
    admin_password = local.grafana_admin_password
    dns_sans       = local.state.metadata.global_pki_map["observability-frontend"].dns_san
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
