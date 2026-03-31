
# 1. External State Context
locals {
  state = {
    metadata            = data.terraform_remote_state.metadata.outputs
    vault_pki           = data.terraform_remote_state.vault_pki.outputs
    redis               = data.terraform_remote_state.redis.outputs
    postgres            = data.terraform_remote_state.postgres.outputs
    minio               = data.terraform_remote_state.minio.outputs
    minio_provision     = data.terraform_remote_state.minio_provision.outputs
    network             = data.terraform_remote_state.network.outputs.infrastructure_map
    kubeadm             = data.terraform_remote_state.kubeadm.outputs
    harbor_bootstrapper = data.terraform_remote_state.harbor_bootstrapper.outputs
    platform            = data.terraform_remote_state.platform_gitlab.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
  }
}

# Kubeadm Configuration & Auth Object
locals {
  kubeconfig   = yamldecode(base64decode(data.vault_generic_secret.kubeconfig.data["content_b64"]))
  cluster_info = local.kubeconfig.clusters[0].cluster
  user_info    = local.kubeconfig.users[0].user

  api_server_connection = {
    host               = local.cluster_info.server
    ca_cert            = base64decode(local.cluster_info["certificate-authority-data"])
    client_certificate = base64decode(local.user_info["client-certificate-data"])
    client_key         = base64decode(local.user_info["client-key-data"])
  }

  # Get Issuer Information from Layer 50 (Trust Engine Contract)
  issuer_name = data.terraform_remote_state.platform_gitlab.outputs.trust_context.issuer_name
  issuer_kind = data.terraform_remote_state.platform_gitlab.outputs.trust_context.issuer_kind
}

# 3. Addons & Trust Engine Context
locals {
  # SSoT Discovery (Direct PKI/Network Mappings)

  # FQDNs
  fqdn_gitlab              = local.state.metadata.global_pki_map["gitlab-frontend"].dns_san[0]
  fqdn_vault               = local.state.metadata.global_pki_map["vault-frontend"].dns_san[0]
  fqdn_harbor_bootstrapper = local.state.metadata.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  fqdn_minio               = local.state.metadata.global_pki_map["gitlab-minio"].dns_san[0]
  fqdn_postgres            = local.state.metadata.global_pki_map["gitlab-postgres"].dns_san[0]
  fqdn_redis               = local.state.metadata.global_pki_map["gitlab-redis"].dns_san[0]

  # Harbor Bootstrapper (Registry Redirection)
  # Use the dynamic PKI key mapping from Layer 00
  harbor_quay_proxy   = local.state.harbor_bootstrapper.proxy_caches.quay_io.project_name
  harbor_k8s_proxy    = local.state.harbor_bootstrapper.proxy_caches.k8s_io.project_name
  harbor_docker_proxy = local.state.harbor_bootstrapper.proxy_caches.docker_hub.project_name

  # K8s API Endpoint for Vault Callback (Standardized)
  api_port     = local.state.metadata.global_topology_network["gitlab"]["frontend"].ports["api-server"].frontend_port
  api_endpoint = "https://${local.state.kubeadm.service_vip}:${local.api_port}"

  # Cluster CA from ConfigMap
  cluster_ca = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]

  # Vault Connection (Standardized)
  vault_api_port = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
  # Map to the specific component identity in Vault PKI
  vault_role_name   = local.state.vault_pki.pki_configuration.component_roles["gitlab-frontend"].name
  vault_auth_path   = local.state.vault_pki.auth_backend_paths["kubernetes"]
  vault_policy_name = "${local.vault_role_name}-pki-policy"

  # Correct Vault HA VIP from Layer 20
  vault_address = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
}

# Vault Generic Secrets
locals {
  postgres_password = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
  redis_password    = data.vault_generic_secret.db_vars.data["redis_requirepass"]
}

# External Service Address & Ports
locals {
  # Dynamic Ports/VIPs from Layer 10 (Shared Load Balancer)
  postgres_rw_port = local.state.network["core-gitlab-postgres"].lb_config.ports["rw-proxy"].frontend_port
  redis_port       = local.state.network["core-gitlab-redis"].lb_config.ports["main"].frontend_port
  minio_port       = local.state.network["core-gitlab-minio"].lb_config.ports["api"].frontend_port

  # VIPs from LB Infrastructure
  postgres_vip  = local.state.network["core-gitlab-postgres"].lb_config.vip
  redis_vip     = local.state.network["core-gitlab-redis"].lb_config.vip
  minio_vip     = local.state.network["core-gitlab-minio"].lb_config.vip
  minio_address = "https://${local.fqdn_minio}:${local.minio_port}"
}

# 5. DNS Configuration (Standardized)
locals {
  dns_hosts = {
    "${local.state.kubeadm.service_vip}"         = local.fqdn_gitlab
    "${local.state.vault_pki.vault_service_vip}" = local.fqdn_vault

    # Dependency Roles
    "${local.state.redis.service_vip}"    = local.fqdn_redis
    "${local.state.postgres.service_vip}" = local.fqdn_postgres
    "${local.state.minio.service_vip}"    = local.fqdn_minio
  }
}

# 6. CA Bundle Configuration
locals {
  ca_bundle_config = {
    name        = "gitlab-ca-bundle" # K8s Secret Name
    secret_name = "gitlab-ca-bundle" # Helm Chart Reference Name

    content = join("\n", [
      base64decode(local.state.vault_pki.pki_configuration.ca_cert),
      base64decode(local.state.vault_pki.bootstrap_ca.content)
    ])
  }
}

# 7. Object Storage Mappings
locals {
  s3_region          = "us-east-1"
  minio_function_map = local.state.minio_provision.minio_function_map
}
