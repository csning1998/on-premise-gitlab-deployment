
module "tigera_calico" {
  source         = "../../modules/kubernetes-addons/tigera-calico"
  pod_subnet     = local.state.kubeadm.kubernetes_config.pod_subnet
  image_registry = local.harbor_registry
  image_path     = local.harbor_quay_proxy
}

# [REFACTORED] Trust Engine Integration
module "platform_trust_engine" {
  source = "../../modules/kubernetes-addons/platform-trust-engine"
  providers = {
    vault = vault.production
  }

  # 1. K8s Cluster Connection (for Vault to call back)
  api_server_connection = {
    host    = local.api_endpoint
    ca_cert = local.cluster_ca
  }

  # 2. Vault Connection (for Cert-Manager to authenticate)
  vault_config = {
    address   = local.vault_address
    ca_cert   = local.vault_ca_cert
    auth_path = local.vault_auth_path
  }

  # 3. Issuer Configuration (The "Contract" between K8s and Vault)
  issuer_config = {
    name             = var.trust_engine_config.issuer_name
    bound_namespaces = var.trust_engine_config.authorized_namespaces
    issue_path       = "sign"
    vault_role_name  = local.vault_role_name
    pki_mount_path   = local.vault_pki_path
    token_policies   = [local.vault_policy_name]
  }

  # 4. Reviewer Identity (The entity that validates tokens)
  reviewer_service_account = {
    name      = "vault-reviewer"
    namespace = "default"
  }

  # 5. Helm Chart Installation
  helm_config = {
    install          = true
    version          = var.cert_manager_config.version
    namespace        = var.cert_manager_config.namespace
    create_namespace = true
    image_registry   = local.harbor_registry
    image_repository = "${local.harbor_quay_proxy}/jetstack"
  }

  # Ensure CNI is ready before installing Cert-Manager
  depends_on = [module.tigera_calico]
}

module "metric_server" {
  source = "../../modules/kubernetes-addons/metric-server"
  helm_config = {
    install          = true
    version          = var.metric_server_config.version
    namespace        = var.metric_server_config.namespace
    create_namespace = true
    image_registry   = local.harbor_registry
    image_repository = "${local.harbor_k8s_proxy}/metrics-server"
  }
  depends_on = [module.platform_trust_engine]
}

module "ingress_nginx" {
  source = "../../modules/kubernetes-addons/ingress-nginx"
  helm_config = {
    install          = true
    version          = var.ingress_nginx_config.version
    namespace        = var.ingress_nginx_config.namespace
    create_namespace = true
    image_registry   = local.harbor_registry
    image_repository = "${local.harbor_k8s_proxy}/ingress-nginx"
  }
  depends_on = [module.platform_trust_engine]
}

module "storage_local_path" {
  source = "../../modules/kubernetes-addons/local-path-provisioner"
  helm_config = {
    install                 = true
    version                 = var.local_path_config.version
    namespace               = var.local_path_config.namespace
    create_namespace        = true
    image_registry          = local.harbor_registry
    image_repository        = "${local.harbor_docker_proxy}/rancher"
    helper_image_repository = "${local.harbor_docker_proxy}/library"
  }
  depends_on = [module.tigera_calico]
}

# CoreDNS Configuration
module "coredns_config" {
  source     = "../../modules/kubernetes-addons/coredns-config"
  depends_on = [module.tigera_calico]

  hosts = local.dns_hosts
}
