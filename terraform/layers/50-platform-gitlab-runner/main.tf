
module "felix_config" {
  source = "../../modules/kubernetes-addons/calico-felix-config"
}

resource "kubernetes_namespace" "gitlab" {
  metadata {
    name = var.gitlab_runner_config.namespace
  }
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
    namespace = var.cert_manager_config.namespace
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

# [PHASE 1.5] Internal DNS Configuration
module "coredns_config" {
  source     = "../../modules/kubernetes-addons/coredns-config"
  depends_on = [module.platform_trust_engine]

  hosts = local.dns_hosts
}

# [PHASE 2] GitLab Runner Deployment
resource "kubernetes_secret" "gitlab_ca_bundle" {
  metadata {
    name      = local.ca_bundle_config.name
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "${local.fqdn_gitlab}.crt" = local.ca_bundle_config.content
  }
}
