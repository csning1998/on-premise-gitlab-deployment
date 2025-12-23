
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

# Get K8s Root CA
data "kubernetes_config_map" "kube_root_ca" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "kube-system"
  }
}

# Set Vault Kubernetes Auth Config (Layer 40 connects to Layer 10)
resource "vault_kubernetes_auth_backend_config" "config" {
  backend = "kubernetes"

  # MicroK8s API Server
  kubernetes_host    = "https://${data.terraform_remote_state.microk8s_provision.outputs.harbor_microk8s_virtual_ip}:16443"
  kubernetes_ca_cert = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]
}

