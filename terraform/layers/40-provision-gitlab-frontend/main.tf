
module "tigera_calico" {
  source         = "../../modules/kubernetes-addons/tigera-calico"
  pod_subnet     = local.state.kubeadm.kubernetes_config.pod_subnet
  image_registry = local.harbor_registry
  image_path     = local.harbor_quay_proxy
  chart_project  = local.helm_chart_project
  mtu            = local.pod_network_mtu - 50
}

module "felix_config" {
  source     = "../../modules/kubernetes-addons/calico-felix-config"
  depends_on = [module.tigera_calico]
}

# Declares the namespace locally because each L40 layer targets a distinct Kubernetes cluster;
# this is declared independently per layer rather than shared.
resource "kubernetes_namespace" "vault_auth" {
  metadata {
    name = "vault-auth"
  }
}

# Trust Engine Integration
module "platform_trust_engine" {
  source     = "../../modules/kubernetes-addons/platform-trust-engine"
  depends_on = [module.tigera_calico, kubernetes_namespace.vault_auth] # Ensure CNI and namespace are ready before installing Cert-Manager
  providers  = { vault = vault.production }

  # 1. K8s Cluster Connection (for Vault to call back)
  api_server_connection = {
    host    = local.api_endpoint
    ca_cert = local.cluster_ca
  }

  # 2. Vault Connection (for Cert-Manager to authenticate)
  vault_config = {
    address   = local.vault_endpoint
    ca_cert   = local.vault_ca_cert
    auth_path = local.vault_auth_path
  }

  # 3. Issuer Configuration (The "Contract" between K8s and Vault)
  issuer_config = {
    name            = var.trust_engine_config.issuer_name
    issue_path      = "sign"
    vault_role_name = local.vault_role_name
    pki_mount_path  = local.vault_pki_path
  }

  # 4. Reviewer Identity (The entity that validates tokens)
  reviewer_service_account = {
    name      = "vault-reviewer"
    namespace = kubernetes_namespace.vault_auth.metadata[0].name
  }

  # 5. Helm Chart Installation
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

module "kubelet_csr_approver" {
  source = "../../modules/kubernetes-addons/kubelet-csr-approver"
  helm_config = {
    install          = true
    create_namespace = false # Already in kube-system
    version          = var.csr_approver_config.version
    namespace        = var.csr_approver_config.namespace
    image_tag        = "v${var.csr_approver_config.version}"
    image_repository = "${local.harbor_ghcr_proxy}/postfinance"
    image_registry   = local.harbor_registry
    chart_project    = local.helm_chart_project
    provider_regex   = local.node_serving_cert_regex
  }
}

module "metric_server" {
  source     = "../../modules/kubernetes-addons/metric-server"
  depends_on = [module.kubelet_csr_approver]

  helm_config = {
    install          = true
    version          = var.metric_server_config.version
    namespace        = var.metric_server_config.namespace
    create_namespace = true
    image_registry   = local.harbor_registry
    image_repository = "${local.harbor_k8s_proxy}/metrics-server"
    chart_project    = local.helm_chart_project
  }
}

module "ingress_nginx" {
  source     = "../../modules/kubernetes-addons/ingress-nginx"
  depends_on = [module.platform_trust_engine]

  helm_config = {
    install          = true
    version          = var.ingress_nginx_config.version
    namespace        = var.ingress_nginx_config.namespace
    create_namespace = true
    image_registry   = local.harbor_registry
    image_repository = "${local.harbor_k8s_proxy}/ingress-nginx"
    chart_project    = local.helm_chart_project
  }

  nginx_config = {
    "use-proxy-protocol" = "true"
  }
}

module "storage_local_path" {
  source     = "../../modules/kubernetes-addons/local-path-provisioner"
  depends_on = [module.tigera_calico]

  helm_config = {
    install                 = true
    version                 = var.local_path_config.version
    namespace               = var.local_path_config.namespace
    create_namespace        = true
    image_registry          = local.harbor_registry
    image_repository        = "${local.harbor_docker_proxy}/rancher"
    helper_image_repository = "${local.harbor_docker_proxy}/library"
    chart_project           = local.helm_chart_project
  }
}

# CoreDNS Configuration
module "coredns_config" {
  source     = "../../modules/kubernetes-addons/coredns-config"
  depends_on = [module.tigera_calico]

  hosts = local.dns_hosts
}

module "reloader" {
  source            = "../../modules/kubernetes-addons/reloader"
  harbor_oci_config = local.reloader_oci_config
}

module "external_secrets" {
  source     = "../../modules/kubernetes-addons/external-secrets"
  depends_on = [module.reloader]

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
