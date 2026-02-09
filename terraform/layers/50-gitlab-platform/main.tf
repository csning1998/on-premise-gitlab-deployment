
module "k8s_calico" {
  source     = "../../modules/kubernetes-addons/tigera-calico"
  pod_subnet = data.terraform_remote_state.kubeadm_provision.outputs.gitlab_pod_subnet
}

# [REFACTORED] Trust Engine Integration
# Replaces the previous "k8s_cert_manager" module.
# This standardizes the identity bootstrapping across Harbor (MicroK8s) and GitLab (Kubeadm).
module "platform_trust_engine" {
  source = "../../modules/kubernetes-addons/platform-trust-engine"

  # 1. K8s Cluster Connection (for Vault to call back)
  k8s_connection = {
    host    = local.k8s_api_endpoint
    ca_cert = local.k8s_cluster_ca
  }

  # 2. Vault Connection (for Cert-Manager to authenticate)
  vault_config = {
    address   = local.vault_address
    ca_cert   = local.vault_ca_cert
    auth_path = local.vault_auth_path
  }

  # 3. Issuer Configuration (The "Contract" between K8s and Vault)
  issuer_config = {
    name             = var.trust_engine_config.issuer_name           # e.g., "vault-issuer"
    issue_path       = "sign"                                        # Matches Vault PKI path convention
    vault_role_name  = local.vault_role_name                         # e.g., "gitlab-frontend-role"
    pki_mount_path   = local.vault_pki_path                          # e.g., "pki/prod"
    bound_namespaces = var.trust_engine_config.authorized_namespaces # e.g., ["gitlab", "cert-manager"]
    token_policies   = [local.vault_policy_name]                     # e.g., ["gitlab-frontend-role-pki-policy"]
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
  }

  # Ensure CNI is ready before installing Cert-Manager
  depends_on = [module.k8s_calico]
}

module "k8s_metric_server" {
  source     = "../../modules/kubernetes-addons/metric-server"
  depends_on = [module.platform_trust_engine]
}

module "k8s_ingress_nginx" {
  source     = "../../modules/kubernetes-addons/ingress-nginx"
  depends_on = [module.platform_trust_engine]
}

module "k8s_storage_local_path" {
  source     = "../../modules/kubernetes-addons/local-path-provisioner"
  depends_on = [module.k8s_calico]
}

# CoreDNS Configuration
module "coredns_config" {
  source     = "../../modules/kubernetes-addons/coredns-config"
  depends_on = [module.k8s_calico]

  hosts = local.dns_hosts
}
