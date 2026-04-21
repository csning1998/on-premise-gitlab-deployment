
# 1. External State Context (State Hub)
locals {
  state = {
    metadata             = data.terraform_remote_state.metadata.outputs
    network              = data.terraform_remote_state.network.outputs.infrastructure_map
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    redis                = data.terraform_remote_state.infra_redis.outputs
    postgres             = data.terraform_remote_state.infra_postgres.outputs
    minio                = data.terraform_remote_state.infra_minio.outputs
    harbor_platform      = data.terraform_remote_state.harbor_platform.outputs
    microk8s_infra       = data.terraform_remote_state.microk8s_infra.outputs
  }
}

# 2. Kubernetes Configuration & Auth Object (Retrieved from Vault KV)
locals {
  kubeconfig   = yamldecode(base64decode(data.vault_kv_secret_v2.kubeconfig.data["content_b64"]))
  cluster_info = local.kubeconfig.clusters[0].cluster
  user_info    = local.kubeconfig.users[0].user

  api_server_connection = {
    host               = local.cluster_info.server
    ca_cert            = base64decode(local.cluster_info["certificate-authority-data"])
    client_certificate = base64decode(local.user_info["client-certificate-data"])
    client_key         = base64decode(local.user_info["client-key-data"])
  }

  # Get Issuer Information from Layer 50 (Trust Engine Contract)
  issuer_name = local.state.harbor_platform.trust_context.issuer_name
  issuer_kind = local.state.harbor_platform.trust_context.issuer_kind
}

# 3. Harbor Identity & Vault Secrets
locals {
  # DISCOVERY FROM METADATA SSoT
  harbor_hostname = local.state.metadata.global_pki_map["harbor-frontend"].dns_san[0]

  # DYNAMIC SECRET RETRIEVAL
  harbor_admin_password = data.vault_kv_secret_v2.harbor_vars.data["harbor_admin_password"]
  harbor_pg_password    = data.vault_kv_secret_v2.harbor_vars.data["harbor_pg_db_password"]
  redis_password        = data.vault_kv_secret_v2.harbor_db.data["redis_requirepass"]

  minio_access_key = data.vault_kv_secret_v2.harbor_s3.data["access_key"]
  minio_secret_key = data.vault_kv_secret_v2.harbor_s3.data["secret_key"]

  # Vault Connection (Standardized)
  vault_address  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_api_port = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
}

# 4. External Service Connectivity (Standardized Discovery)
locals {
  # Discover Ports/Names from Metadata & Network Map
  # Harbor Postgres RW Proxy
  postgres_address = local.state.metadata.global_pki_map["harbor-postgres"].dns_san[0]
  postgres_rw_port = local.state.network["core-harbor-postgres"].lb_config.ports["rw-proxy"].frontend_port

  # Harbor Redis HA Proxy
  redis_address = local.state.metadata.global_pki_map["harbor-redis"].dns_san[0]
  redis_port    = local.state.network["core-harbor-redis"].lb_config.ports["main"].frontend_port

  # Harbor MinIO S3 API
  minio_hostname = local.state.metadata.global_pki_map["harbor-minio"].dns_san[0]
  minio_port     = local.state.network["core-harbor-minio"].lb_config.ports["api"].frontend_port
  minio_address  = "https://${local.minio_hostname}:${local.minio_port}"
}

# 5. CA Bundle Configuration (Dynamic Merging)
locals {
  ca_bundle_config = {
    name        = "harbor-ca-bundle" # K8s Secret Name
    secret_name = "harbor-ca-bundle" # Helm Chart Reference Name

    content = join("\n", [
      base64decode(local.state.vault_pki.pki_configuration.ca_cert),
      base64decode(local.state.vault_pki.bootstrap_ca.content)
    ])
  }
}
