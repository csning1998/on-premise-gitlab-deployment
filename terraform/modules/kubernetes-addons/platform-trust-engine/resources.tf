
# Create Reviewer Service Account
resource "kubernetes_service_account" "vault_reviewer" {
  metadata {
    name      = var.reviewer_service_account.name
    namespace = var.reviewer_service_account.namespace
  }
}

# Grant Reviewer the authority to verify Token (system:auth-delegator)
resource "kubernetes_cluster_role_binding" "vault_reviewer" {
  metadata {
    name = "${var.reviewer_service_account.name}-binding"
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

# Explicitly create Long-Lived Token (compatible with K8s 1.24+) due to Terraform dependency chain: SA -> Secret -> Vault Config
resource "kubernetes_secret" "vault_reviewer_token" {
  metadata {
    name      = "${var.reviewer_service_account.name}-token"
    namespace = var.reviewer_service_account.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.vault_reviewer.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

# Configure Vault's Kubernetes Auth Method that K8s Host, CA and Reviewer Token are injected into Vault
resource "vault_kubernetes_auth_backend_config" "config" {
  backend                = var.vault_config.auth_path
  kubernetes_host        = var.k8s_connection.host
  kubernetes_ca_cert     = var.k8s_connection.ca_cert
  token_reviewer_jwt     = kubernetes_secret.vault_reviewer_token.data["token"]
  disable_iss_validation = true
}

# Install Cert Manager (if not already installed, controlled by variable)
resource "helm_release" "cert_manager" {
  count            = var.helm_config.install ? 1 : 0
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.helm_config.version
  namespace        = var.helm_config.namespace
  create_namespace = var.helm_config.create_namespace

  set = [
    {
      name  = "installCRDs"
      value = "true"
    }
  ]
}

# Create Issuer's Service Account (Client Identity)
resource "kubernetes_service_account" "issuer" {

  depends_on = [helm_release.cert_manager]

  metadata {
    name      = "${var.issuer_config.name}-sa"
    namespace = var.helm_config.namespace
  }
}

# Create Issuer's Secret (Client Token) to prove its identity to Vault
resource "kubernetes_secret" "issuer_token" {
  metadata {
    name      = "${var.issuer_config.name}-token"
    namespace = var.helm_config.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.issuer.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

# Create Vault Role (Server Permission) to bind the Issuer SA and restrict it to only issue certificates with specific policies
resource "vault_kubernetes_auth_backend_role" "issuer" {
  backend   = var.vault_config.auth_path
  role_name = var.issuer_config.vault_role_name

  bound_service_account_names      = [kubernetes_service_account.issuer.metadata[0].name]
  bound_service_account_namespaces = [kubernetes_service_account.issuer.metadata[0].namespace]

  token_policies    = var.issuer_config.token_policies
  alias_name_source = "serviceaccount_name"
}

# Create ClusterIssuer Resource (K8s Resource) that Layer 60 will reference as "issuerRef"
resource "kubectl_manifest" "cluster_issuer" {

  depends_on = [helm_release.cert_manager]

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = var.issuer_config.name
    }
    spec = {
      vault = {
        path     = "${var.issuer_config.pki_mount_path}/${var.issuer_config.issue_path}/${var.issuer_config.vault_role_name}"
        server   = var.vault_config.address
        caBundle = base64encode(var.vault_config.ca_cert)

        auth = {
          kubernetes = {
            role      = var.issuer_config.vault_role_name
            mountPath = "/v1/auth/${var.vault_config.auth_path}"
            secretRef = {
              name = kubernetes_secret.issuer_token.metadata[0].name
              key  = "token"
            }
          }
        }
      }
    }
  })
}
