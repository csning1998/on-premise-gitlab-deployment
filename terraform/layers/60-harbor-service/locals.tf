
# Microk8s Configuration & Auth Object
locals {
  kubeconfig_raw = data.terraform_remote_state.microk8s_provision.outputs.kubeconfig_content
  kubeconfig     = yamldecode(local.kubeconfig_raw)

  # Encapsulate K8s Auth Object for Provider Usage
  k8s_provider_auth = {
    host                   = local.kubeconfig.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.kubeconfig.users[0].user["client-certificate-data"])
    client_key             = base64decode(local.kubeconfig.users[0].user["client-key-data"])
  }

  # Get Issuer Information from Layer 50
  issuer_name = data.terraform_remote_state.harbor_platform.outputs.platform_issuer_name
  issuer_kind = data.terraform_remote_state.harbor_platform.outputs.platform_issuer_kind
}

# Vault Generic Secrets
locals {
  vm_username      = data.vault_generic_secret.variables.data["vm_username"]
  private_key_path = data.vault_generic_secret.variables.data["ssh_private_key_path"]

  minio_access_key = data.vault_generic_secret.s3_credentials.data["access_key"]
  minio_secret_key = data.vault_generic_secret.s3_credentials.data["secret_key"]

  harbor_pg_password    = data.vault_generic_secret.harbor_vars.data["harbor_pg_db_password"]
  redis_password        = data.vault_generic_secret.db_vars.data["redis_requirepass"]
  harbor_admin_password = data.vault_generic_secret.harbor_vars.data["harbor_admin_password"]
}

# External Service Port.
locals {
  postgres_rw_port = data.terraform_remote_state.postgres.outputs.harbor_postgres_haproxy_rw_port
  redis_port       = data.terraform_remote_state.redis.outputs.harbor_redis_haproxy_stats_port
  minio_port       = data.terraform_remote_state.minio.outputs.harbor_minio_haproxy_ports.backend_port_api
}

# External Service Address. The format should abide by the Helm Chart requirement.
locals {
  harbor_hostname  = data.terraform_remote_state.vault_pki.outputs.pki_configuration.component_roles["harbor-frontend"].allowed_domains[0]
  postgres_address = data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["harbor-postgres"].allowed_domains[0]
  redis_address    = "${data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["harbor-redis"].allowed_domains[0]}:${local.redis_port}"
  minio_address    = "https://${data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["harbor-minio"].allowed_domains[0]}:${local.minio_port}"
}

locals {
  ca_bundle_config = {
    name        = "harbor-ca-bundle" # K8s Secret Name
    secret_name = "harbor-ca-bundle" # Helm Chart Reference Name

    content = join("\n", [
      data.terraform_remote_state.vault_pki.outputs.vault_certificates.ca_cert.ca_cert,
      data.http.vault_pki_ca.response_body
    ])
  }
}
