# 1. External State Context
locals {
  state = {
    metadata            = data.terraform_remote_state.metadata.outputs
    vault_pki           = data.terraform_remote_state.vault_pki.outputs
    redis               = data.terraform_remote_state.redis.outputs
    postgres            = data.terraform_remote_state.postgres.outputs
    minio               = data.terraform_remote_state.minio.outputs
    kubeadm             = data.terraform_remote_state.kubeadm.outputs
    harbor_bootstrapper = data.terraform_remote_state.harbor_bootstrapper.outputs
  }
}

# 2. K8s Provider Authentication Context
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

# 3. Addons & Trust Engine Context
locals {
  # SSoT Discovery (Direct PKI/Network Mappings)
  
  # FQDNs
  gitlab_fqdn = local.state.metadata.global_pki_map["gitlab-frontend"].dns_san[0]
  vault_fqdn  = local.state.metadata.global_pki_map["vault-frontend"].dns_san[0]

  # Harbor Bootstrapper (Registry Redirection)
  # Use the dynamic PKI key mapping from Layer 00
  harbor_registry     = local.state.metadata.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  harbor_quay_proxy   = local.state.harbor_bootstrapper.proxy_caches.quay_io.project_name
  harbor_k8s_proxy    = local.state.harbor_bootstrapper.proxy_caches.k8s_io.project_name
  harbor_docker_proxy = local.state.harbor_bootstrapper.proxy_caches.docker_hub.project_name

  # K8s API Endpoint for Vault Callback (Standardized)
  api_port     = local.state.metadata.global_topology_network["gitlab"]["frontend"].ports["api-server"].frontend_port
  api_endpoint = "https://${local.state.kubeadm.service_vip}:${local.api_port}"

  # Cluster CA from ConfigMap
  cluster_ca = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]

  # Vault Connection (Standardized)
  vault_api_port    = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
  vault_address     = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_ca_cert     = local.state.vault_pki.bootstrap_ca.content
  vault_pki_path    = local.state.vault_pki.pki_configuration.path
  
  # Map to the specific component identity in Vault PKI
  vault_role_name   = local.state.vault_pki.pki_configuration.component_roles["gitlab-frontend"].name
  vault_auth_path   = local.state.vault_pki.auth_backend_paths["kubernetes"]
  vault_policy_name = "${local.vault_role_name}-pki-policy"
}

# 4. DNS Configuration (Standardized)
locals {
  dns_hosts = {
    "${local.state.kubeadm.service_vip}"   = local.gitlab_fqdn
    "${local.state.vault_pki.vault_service_vip}" = local.vault_fqdn

    # Dependency Roles
    "${local.state.redis.service_vip}"    = local.state.metadata.global_pki_map["gitlab-redis"].dns_san[0]
    "${local.state.postgres.service_vip}" = local.state.metadata.global_pki_map["gitlab-postgres"].dns_san[0]
    "${local.state.minio.service_vip}"    = local.state.metadata.global_pki_map["gitlab-minio"].dns_san[0]
  }
}
