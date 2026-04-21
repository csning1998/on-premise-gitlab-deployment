
# Generic Namespace is provided by the caller
# CA Bundle Secret (Trust Anchor)
resource "kubernetes_secret" "gitlab_ca_bundle" {
  metadata {
    name      = var.ca_bundle.name
    namespace = var.helm_config.namespace
  }
  data = {
    "ca.crt" = var.ca_bundle.content
  }

  lifecycle {
    ignore_changes = [
      data,
      metadata[0].labels,
      metadata[0].annotations,
    ]
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

  lifecycle {
    ignore_changes = [
      data,
      metadata[0].labels,
      metadata[0].annotations,
    ]
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

  lifecycle {
    ignore_changes = [
      data,
      metadata[0].labels,
      metadata[0].annotations,
    ]
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

  lifecycle {
    ignore_changes = [
      data,
      metadata[0].labels,
      metadata[0].annotations,
    ]
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

  lifecycle {
    ignore_changes = [
      data,
      metadata[0].labels,
      metadata[0].annotations,
    ]
  }
}
