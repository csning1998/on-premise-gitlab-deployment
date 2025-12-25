
# Install Cert-Manager (Helm Chart)
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.14.0"
  namespace        = "cert-manager"
  create_namespace = true

  set = [
    {
      name  = "installCRDs"
      value = "true"
    }
  ]
}

# Get Kubernetes Root CA
data "kubernetes_config_map" "kube_root_ca" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "kube-system"
  }
}

# 1. Reviewer Service Account for Vault to examine Kubernetes Token
resource "kubernetes_service_account" "vault_reviewer" {
  metadata {
    name      = "vault-reviewer"
    namespace = "default" # put in default namespace for easy management. possibly need future refactoring
  }
}

# 2. Assign system:auth-delegator permission to let it call TokenReview API
resource "kubernetes_cluster_role_binding" "vault_reviewer" {
  metadata {
    name = "role-tokenreview-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_reviewer.metadata[0].name
    namespace = kubernetes_service_account.vault_reviewer.metadata[0].namespace
  }
}

# 3. Create Reviewer Long-Lived Token Secret
resource "kubernetes_secret" "vault_reviewer_token" {
  metadata {
    name      = "vault-reviewer-token"
    namespace = "default"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.vault_reviewer.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

/** 4. Set Vault Auth Backend Config (feed Reviewer Token to Vault)
 * Use physical IP to bypass VIP L2 issue
 * Inject Kubernetes CA (automatically read from Secret)
 * Inject Reviewer Token (let Vault has permission to examine)
 * Close Issuer validation (resolve iss mismatch)
 */
resource "vault_kubernetes_auth_backend_config" "config" {
  backend                = "kubernetes"
  kubernetes_host        = "https://${local.microk8s_physical_ip}:${var.microk8s_api_port}"
  kubernetes_ca_cert     = kubernetes_secret.vault_reviewer_token.data["ca.crt"]
  token_reviewer_jwt     = kubernetes_secret.vault_reviewer_token.data["token"]
  disable_iss_validation = true

  # Specific Audience can be specified if needed. e.g. issuer = "https://kubernetes.default.svc"
}

# 5. Set Vault Role for Cert-Manager to login
resource "vault_kubernetes_auth_backend_role" "issuer" {
  backend   = "kubernetes"
  role_name = "harbor-issuer"

  # Bind the SA that used in ClusterIssuer
  bound_service_account_names      = ["vault-issuer"]
  bound_service_account_namespaces = ["cert-manager"]

  # Use Name verification to avoid Pod rebuild causing UID change and verification failure
  alias_name_source = "serviceaccount_name"
  token_policies    = ["harbor-pki-policy"] # Assign Layer 10 created policy
}
