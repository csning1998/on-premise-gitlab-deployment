
# Generic Namespace
resource "kubernetes_namespace" "gitlab_ns" {
  metadata {
    name = var.helm_config.namespace
  }
}

# Certificate CR (Delegated to Trust Engine / Cert-Manager)
resource "kubernetes_manifest" "gitlab_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = var.ingress_config.tls_secret_name
      namespace = var.helm_config.namespace
    }
    spec = {
      secretName = var.ingress_config.tls_secret_name
      issuerRef = {
        name = var.ingress_config.issuer_name
        kind = var.ingress_config.issuer_kind
      }
      commonName  = var.gitlab_config.hostname
      dnsNames    = [var.gitlab_config.hostname]
      duration    = var.certificate_config.duration
      renewBefore = var.certificate_config.renew_before
    }
  }
}

# CA Bundle Secret (Trust Anchor)
resource "kubernetes_secret" "gitlab_ca_bundle" {
  metadata {
    name      = var.ca_bundle.name
    namespace = var.helm_config.namespace
  }
  data = {
    "ca.crt" = var.ca_bundle.content
  }
}

# External Service Secrets (DB & Redis)
resource "kubernetes_secret" "gitlab_postgres_password" {
  metadata {
    name      = "gitlab-postgres-password"
    namespace = var.helm_config.namespace
  }
  data = {
    password = var.external_services.postgres.password
  }
}

resource "kubernetes_secret" "gitlab_redis_password" {
  metadata {
    name      = "gitlab-redis-password"
    namespace = var.helm_config.namespace
  }
  data = {
    password = var.external_services.redis.password
  }
}

# MinIO Connection YAML (GitLab Specific Format)
resource "kubernetes_secret" "gitlab_minio_secrets" {

  for_each = var.external_services.minio.buckets

  metadata {
    name      = "gitlab-minio-${each.key}"
    namespace = var.helm_config.namespace
  }
  data = {
    connection = yamlencode({
      provider              = "AWS"
      region                = var.external_services.minio.region
      endpoint              = var.external_services.minio.endpoint
      aws_access_key_id     = each.value.access_key
      aws_secret_access_key = each.value.secret_key
      path_style            = true
    })
  }
}

resource "kubernetes_secret" "gitlab_internal_secrets" {
  for_each = var.gitlab_secrets

  metadata {
    name      = each.key
    namespace = var.helm_config.namespace
  }

  type = "Opaque"

  data = {
    (each.value.key) = each.value.value
  }
}
