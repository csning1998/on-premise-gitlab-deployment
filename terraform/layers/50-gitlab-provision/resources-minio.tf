
resource "kubernetes_secret" "gitlab_s3" {
  for_each = data.vault_generic_secret.s3_credentials

  metadata {
    name      = each.key
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    connection = yamlencode({
      provider              = "AWS"
      region                = local.s3_region
      endpoint              = local.s3_endpoint
      aws_access_key_id     = each.value.data["access_key"]
      aws_secret_access_key = each.value.data["secret_key"]
      path_style            = true
    })
  }
}
