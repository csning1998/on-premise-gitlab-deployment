
module "felix_config" {
  source = "../../modules/kubernetes-addons/calico-felix-config"
}

module "platform_trust_engine" {
  source     = "../../modules/kubernetes-addons/platform-trust-engine"
  depends_on = [module.felix_config]
  providers  = { vault = vault.production }

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

module "external_secrets" {
  source     = "../../modules/kubernetes-addons/external-secrets"
  depends_on = [module.platform_trust_engine, module.reloader]

  helm_config = {
    install          = true
    version          = "2.5.0"
    namespace        = "external-secrets"
    create_namespace = true
    image_registry   = local.harbor_registry
    image_repository = "${local.harbor_ghcr_proxy}/external-secrets/external-secrets"
    chart_project    = local.helm_chart_project
  }
}
