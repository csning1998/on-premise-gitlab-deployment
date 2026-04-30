
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
    name             = "vault-issuer"
    bound_namespaces = ["gitlab", "default"]
    issue_path       = "sign"
    vault_role_name  = local.vault_role_name
    pki_mount_path   = local.vault_pki_path
    token_policies   = [local.vault_policy_name]
  }

  reviewer_service_account = {
    name      = "vault-reviewer"
    namespace = "default"
  }

  helm_config = {
    install          = true
    version          = "v1.14.0"
    namespace        = "cert-manager"
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
    version          = "3.13.0"
    namespace        = "kube-system"
    create_namespace = false
    image_registry   = local.harbor_registry
    image_repository = "${local.harbor_k8s_proxy}/metrics-server"
    chart_project    = local.helm_chart_project
  }

  depends_on = [module.platform_trust_engine]
}

# [PHASE 2] GitLab Runner Deployment
resource "kubernetes_secret" "gitlab_ca_bundle" {
  metadata {
    name      = local.ca_bundle_config.name
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "ca.crt" = local.ca_bundle_config.content
  }
}

resource "helm_release" "gitlab_runner" {
  name       = "gitlab-runner"
  repository = "oci://${local.harbor_registry}/${local.helm_chart_project}"
  chart      = "gitlab-runner"
  version    = var.gitlab_runner_config.version
  namespace  = kubernetes_namespace.gitlab.metadata[0].name

  values = [
    yamlencode({
      gitlabUrl = local.gitlab_url
      rbac = {
        create = true
      }
      runnerToken     = local.runner_token
      certsSecretName = kubernetes_secret.gitlab_ca_bundle.metadata[0].name

      image = {
        registry   = local.harbor_registry
        image      = "${local.harbor_docker_proxy}/gitlab/gitlab-runner"
        tag        = "alpine-v16.8.0"
        pullPolicy = "IfNotPresent"
      }

      runners = {
        config = <<-EOT
          [[runners]]
            [runners.kubernetes]
              namespace = "${kubernetes_namespace.gitlab.metadata[0].name}"
              image = "${local.harbor_registry}/${local.harbor_docker_proxy}/alpine:latest"
              helper_image = "${local.runner_helper_image}"
              privileged = true
        EOT
      }

      securityContext = {
        fsGroup = 65533
        runAsUser = 100
      }
    })
  ]

  depends_on = [
    module.platform_trust_engine,
    kubernetes_secret.gitlab_ca_bundle
  ]
}
