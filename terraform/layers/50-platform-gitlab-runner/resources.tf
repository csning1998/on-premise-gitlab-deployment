
# 1. Runner Token Kubernetes Secret
resource "kubernetes_secret" "runner_token" {
  metadata {
    name      = "gitlab-runner-token"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "runner-token"              = data.vault_kv_secret_v2.gitlab_runner.data["token"]
    "runner-registration-token" = data.vault_kv_secret_v2.gitlab_runner.data["token"]
  }
}

# 2. CI/CD Job Deployer ServiceAccount
resource "kubernetes_service_account" "gitlab_ci_deployer" {
  metadata {
    name      = "gitlab-ci-deployer"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }
}

# 3. CI/CD Job Deployer Role
resource "kubernetes_role" "gitlab_ci_deployer_role" {
  metadata {
    name      = "gitlab-ci-deployer-role"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  rule {
    api_groups = ["apps", ""]
    resources  = ["deployments", "services", "ingresses", "configmaps", "secrets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

# 4. CI/CD Job Deployer RoleBinding
resource "kubernetes_role_binding" "gitlab_ci_deployer_binding" {
  metadata {
    name      = "gitlab-ci-deployer-binding"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.gitlab_ci_deployer.metadata[0].name
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.gitlab_ci_deployer_role.metadata[0].name
  }
}

# 5. GitLab Runner Helm Chart Deployment
resource "helm_release" "gitlab_runner" {
  name             = "gitlab-runner"
  chart            = "oci://${local.harbor_registry}/${local.helm_chart_project}/gitlab-runner"
  namespace        = kubernetes_namespace.gitlab.metadata[0].name
  version          = var.gitlab_runner_config.version
  create_namespace = false

  depends_on = [
    kubernetes_secret.runner_token,
    kubernetes_secret.gitlab_ca_bundle
  ]

  values = [
    yamlencode({
      gitlabUrl = "https://${local.fqdn_gitlab}"
      rbac      = { create = true }

      hostAliases = [
        {
          ip        = local.state.provision.network_context.vip_gitlab_frontend
          hostnames = [local.fqdn_gitlab]
        }
      ]

      image = {
        registry = local.harbor_registry
        image    = "${local.harbor_gitlab_proxy}/gitlab-org/gitlab-runner"
      }

      certsSecretName = kubernetes_secret.gitlab_ca_bundle.metadata[0].name

      runners = {
        secret = kubernetes_secret.runner_token.metadata[0].name

        config = templatefile("${path.module}/templates/runner-config.toml.tftpl", {
          harbor_registry       = local.harbor_registry
          harbor_docker_proxy   = local.harbor_docker_proxy
          namespace             = kubernetes_namespace.gitlab.metadata[0].name
          service_account       = kubernetes_service_account.gitlab_ci_deployer.metadata[0].name
          pod_network_mtu       = local.pod_network_mtu
          gitlab_ca_bundle_name = kubernetes_secret.gitlab_ca_bundle.metadata[0].name
          fqdn_gitlab           = local.fqdn_gitlab
        })
      }
    })
  ]
}
