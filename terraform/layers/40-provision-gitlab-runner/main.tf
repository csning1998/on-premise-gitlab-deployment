
module "felix_config" {
  source = "../../modules/kubernetes-addons/calico-felix-config"
}

# Each L40 layer targets its own Kubernetes cluster, so this namespace is declared
# independently per layer rather than shared; it is not a duplicate to be consolidated.
resource "kubernetes_namespace" "vault_auth" {
  metadata {
    name = "vault-auth"
  }
}

module "platform_trust_engine" {
  source = "../../modules/kubernetes-addons/platform-trust-engine"
  providers = {
    vault = vault.production
  }
  depends_on = [module.felix_config, kubernetes_namespace.vault_auth]

  api_server_connection = {
    host    = local.api_endpoint
    ca_cert = local.cluster_ca
  }

  vault_config = {
    address   = local.vault_endpoint
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
    namespace = kubernetes_namespace.vault_auth.metadata[0].name
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

module "metric_server" {
  source = "../../modules/kubernetes-addons/metric-server"
  helm_config = {
    install          = true
    version          = var.metric_server_config.version
    namespace        = var.metric_server_config.namespace
    create_namespace = false
    image_registry   = local.harbor_registry
    image_repository = "${local.harbor_k8s_proxy}/metrics-server"
    chart_project    = local.helm_chart_project
  }

  depends_on = [module.platform_trust_engine]
}

module "coredns_config" {
  source     = "../../modules/kubernetes-addons/coredns-config"
  depends_on = [module.platform_trust_engine]

  hosts = local.dns_hosts
}
