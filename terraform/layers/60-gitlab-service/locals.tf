
# Kubeadm Configuration & Auth Object
locals {
  kubeconfig_raw = data.terraform_remote_state.kubeadm_provision.outputs.kubeconfig_content
  kubeconfig     = yamldecode(local.kubeconfig_raw)

  # Encapsulate K8s Auth Object for Provider Usage (Standardized with Harbor)
  k8s_provider_auth = {
    host                   = local.kubeconfig.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.kubeconfig.users[0].user["client-certificate-data"])
    client_key             = base64decode(local.kubeconfig.users[0].user["client-key-data"])
  }

  # Get Issuer Information from Layer 50 (Trust Engine Contract)
  issuer_name = data.terraform_remote_state.gitlab_platform.outputs.trust_context.issuer_name
  issuer_kind = data.terraform_remote_state.gitlab_platform.outputs.trust_context.issuer_kind
}

# Vault Generic Secrets
locals {
  postgres_password = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
  redis_password    = data.vault_generic_secret.db_vars.data["redis_requirepass"]
}

# External Service Address & Ports
locals {
  gitlab_hostname  = data.terraform_remote_state.vault_pki.outputs.pki_configuration.component_roles["gitlab-frontend"].allowed_domains[0]
  minio_hostname   = data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["gitlab-minio"].allowed_domains[0]
  postgres_rw_port = data.terraform_remote_state.postgres.outputs.gitlab_postgres_haproxy_rw_port
  redis_port       = data.terraform_remote_state.redis.outputs.gitlab_redis_haproxy_stats_port
  minio_port       = data.terraform_remote_state.minio.outputs.gitlab_minio_haproxy_ports.backend_port_api

  postgres_vip  = data.terraform_remote_state.postgres.outputs.gitlab_postgres_virtual_ip
  redis_vip     = data.terraform_remote_state.redis.outputs.gitlab_redis_virtual_ip
  minio_vip     = data.terraform_remote_state.minio.outputs.gitlab_minio_virtual_ip
  minio_address = "https://${local.minio_hostname}:${local.minio_port}"
}

locals {
  ca_bundle_config = {
    name        = "gitlab-ca-bundle" # K8s Secret Name
    secret_name = "gitlab-ca-bundle" # Helm Chart Reference Name

    content = join("\n", [
      data.terraform_remote_state.vault_pki.outputs.vault_certificates.ca_cert.ca_cert,
      data.http.vault_pki_ca.response_body
    ])
  }
}

locals {
  s3_region = "us-east-1"
  minio_function_map = {
    "artifacts"       = "gitlab-artifacts"
    "lfs"             = "gitlab-lfs"
    "uploads"         = "gitlab-uploads"
    "packages"        = "gitlab-packages"
    "terraform-state" = "gitlab-terraform-state"
    "backups"         = "gitlab-backups"
    "tmp"             = "gitlab-tmp-backups"
  }
}
