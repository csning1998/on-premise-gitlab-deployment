
# External State Context
locals {
  state = {
    metadata             = data.terraform_remote_state.metadata.outputs
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    redis                = data.terraform_remote_state.redis.outputs
    postgres             = data.terraform_remote_state.postgres.outputs
    minio                = data.terraform_remote_state.minio.outputs
    microk8s_provision   = data.terraform_remote_state.microk8s_provision.outputs
    harbor_bootstrapper  = data.terraform_remote_state.harbor_bootstrapper.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
  }
}

# K8s Provider Authentication Context
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
}

# Addons & Trust Engine Context
locals {
  # FQDNs
  harbor_fqdn = local.state.metadata.global_pki_map["harbor-frontend"].dns_san[0]
  vault_fqdn  = local.state.metadata.global_pki_map["vault-frontend"].dns_san[0]

  # Harbor Bootstrapper (Registry Redirection)
  harbor_registry     = local.state.metadata.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  harbor_quay_proxy   = local.state.harbor_bootstrapper.proxy_caches.quay_io.project_name
  harbor_k8s_proxy    = local.state.harbor_bootstrapper.proxy_caches.k8s_io.project_name
  harbor_docker_proxy = local.state.harbor_bootstrapper.proxy_caches.docker_hub.project_name

  # K8s API Endpoint for Vault Callback (Standardized)
  api_port     = local.state.metadata.global_topology_network["harbor"]["frontend"].ports["api-server"].frontend_port
  api_endpoint = "https://${local.state.microk8s_provision.harbor_microk8s_ip_list[0]}:${local.api_port}"

  # Cluster CA from ConfigMap
  cluster_ca = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]

  # Vault Connection (Standardized)
  vault_api_port = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
  vault_address  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_ca_cert  = local.state.vault_pki.bootstrap_ca.content
  vault_pki_path = local.state.vault_pki.pki_configuration.path

  # Dependency Ports (Standardized)
  pg_port = local.state.metadata.global_topology_network["harbor"]["postgres"].ports["rw-proxy"].frontend_port

  # Map to the specific component identity in Vault PKI
  vault_role_name   = local.state.vault_pki.pki_configuration.component_roles["harbor-frontend"].name
  vault_auth_path   = local.state.vault_pki.auth_backend_paths["kubernetes"]
  vault_policy_name = "${local.vault_role_name}-pki-policy"
}

# 4. Vault Generic Secrets
locals {
  harbor_pg_db_password = data.vault_generic_secret.harbor_vars.data["harbor_pg_db_password"]
  harbor_admin_password = data.vault_generic_secret.harbor_vars.data["harbor_admin_password"]
}

# 5. DNS Configuration (Standardized)
locals {
  # Explicitly extract IPs to avoid implicit map projection failures
  harbor_vip   = local.state.microk8s_provision.harbor_microk8s_virtual_ip
  vault_vip    = local.state.vault_pki.vault_service_vip
  redis_vip    = local.state.redis.service_vip
  postgres_vip = local.state.postgres.service_vip
  minio_vip    = local.state.minio.service_vip

  # Explicitly extract FQDNs
  redis_fqdn    = local.state.metadata.global_pki_map["harbor-redis"].dns_san[0]
  postgres_fqdn = local.state.metadata.global_pki_map["harbor-postgres"].dns_san[0]
  minio_fqdn    = local.state.metadata.global_pki_map["harbor-minio"].dns_san[0]

  dns_hosts = {
    "${local.harbor_vip}" = "${local.harbor_fqdn} notary.${local.harbor_fqdn}"
    "${local.vault_vip}"  = local.vault_fqdn

    # Dependency Roles (Explicitly Mapping)
    "${local.redis_vip}"    = local.redis_fqdn
    "${local.postgres_vip}" = local.postgres_fqdn
    "${local.minio_vip}"    = local.minio_fqdn

    # Registry Redirection (SSoT)
    "${local.state.harbor_bootstrapper.service_vip}" = local.harbor_registry
  }
}
