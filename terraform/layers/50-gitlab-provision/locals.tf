
locals {
  kubeconfig_raw = data.terraform_remote_state.gitlab_cluster.outputs.kubeconfig_content
  kubeconfig     = yamldecode(local.kubeconfig_raw)

  cluster_info = local.kubeconfig.clusters[0].cluster
  user_info    = local.kubeconfig.users[0].user
}

locals {
  s3_endpoint = data.vault_generic_secret.s3_artifacts.data["endpoint"]
  s3_region   = "us-east-1"
  s3_bucket_names = toset([
    "gitlab-artifacts",
    "gitlab-lfs",
    "gitlab-uploads",
    "gitlab-packages",
    "gitlab-terraform-state",
    "gitlab-backups"
  ])
}

locals {
  gitlab_secrets = {
    "rails-secret"  = { length = 64, special = false, key = "secret" }
    "shell-secret"  = { length = 64, special = false, key = "secret" }
    "gitaly-secret" = { length = 64, special = false, key = "token" }
    "root-password" = { length = 24, special = false, key = "password" }
  }
}
