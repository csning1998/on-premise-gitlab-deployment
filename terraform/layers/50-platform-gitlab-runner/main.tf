
resource "kubernetes_namespace" "gitlab" {
  metadata {
    name = var.gitlab_runner_config.namespace
  }
}

resource "kubernetes_secret" "gitlab_ca_bundle" {
  metadata {
    name      = local.ca_bundle_config.name
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "${local.fqdn_gitlab}.crt" = local.ca_bundle_config.content
  }
}

resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
  }
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
    cluster_label         = "gitlab-runner"
    tenant_id             = "gitlab-runner"
    mtls_cert_secret_name = module.alloy_client_cert.secret_name
  }
}
