
# 0. Run init-secrets.sh via local-exec during terraform apply
resource "terraform_data" "seed_rails_secrets" {
  provisioner "local-exec" {
    environment = {
      VAULT_ADDR      = local.vault_endpoint
      VAULT_CACERT    = local.state.vault_pki.bootstrap_ca_b64.path
      VAULT_ROLE_ID   = local.state.vault_prod_bootstrap.production_role_id
      VAULT_SECRET_ID = local.state.vault_prod_bootstrap.production_secret_id
    }
    interpreter = ["bash", "-c"]
    command = templatefile("${path.module}/templates/seed-rails-secrets.sh.tftpl", {
      rails_path = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/gitlab/app/rails-secrets"
    })
  }
}

# 1. Vault authentication for the gitlab namespace
resource "kubernetes_manifest" "gitlab_vault_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "gitlab-vault-store"
      namespace = kubernetes_namespace.gitlab_ns.metadata[0].name
    }
    spec = {
      provider = {
        vault = {
          server   = "https://${local.vault_fqdn}:8200"
          path     = "secret"
          version  = "v2"
          caBundle = local.state.vault_pki.bootstrap_ca_b64.content_b64
          auth = {
            kubernetes = {
              mountPath = "kubernetes/gitlab/frontend"
              role      = "core-gitlab-frontend-role"
              serviceAccountRef = {
                name = "default"
              }
            }
          }
        }
      }
    }
  }
}


# 2. Assembles gitlab-rails-secret from Vault KV
resource "kubernetes_manifest" "gitlab_rails_secret_eso" {
  depends_on = [
    kubernetes_manifest.gitlab_vault_secret_store,
    terraform_data.seed_rails_secrets,
  ]

  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "gitlab-rails-secret"
      namespace = kubernetes_namespace.gitlab_ns.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "gitlab-vault-store"
        kind = "SecretStore"
      }
      target = {
        name           = "gitlab-rails-secret"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "secrets.yml"
          remoteRef = {
            key      = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/gitlab/app/rails-secrets"
            property = "secrets_yml"
          }
        }
      ]
    }
  }
}
