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
  # SSoT Discovery
  ssot_gitlab = local.state.metadata.global_service_structure["gitlab"]
  ssot_vault  = local.state.metadata.global_service_structure["vault"]

  # FQDNs
  gitlab_fqdn = local.ssot_gitlab.components["frontend"].role.dns_san[0]
  vault_fqdn  = local.ssot_vault.components["raft"].role.dns_san[0]

  # Harbor Bootstrapper (Registry Redirection)
  harbor_registry     = local.state.metadata.global_service_structure["harbor-bootstrapper"].components.frontend.role.dns_san[0]
  harbor_quay_proxy   = local.state.harbor_bootstrapper.proxy_caches.quay_io.project_name
  harbor_k8s_proxy    = local.state.harbor_bootstrapper.proxy_caches.k8s_io.project_name
  harbor_docker_proxy = local.state.harbor_bootstrapper.proxy_caches.docker_hub.project_name

  # K8s API Endpoint for Vault Callback (Standardized)
  api_port     = local.ssot_gitlab.meta.ports["api-server"].frontend_port
  api_endpoint = "https://${local.state.kubeadm.service_vip}:${local.api_port}"

  # Cluster CA from ConfigMap
  cluster_ca = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]

  # Vault Connection (Standardized)
  vault_api_port    = local.ssot_vault.meta.ports["api"].frontend_port
  vault_address     = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_ca_cert     = local.state.vault_pki.bootstrap_ca.content
  vault_pki_path    = local.state.vault_pki.pki_configuration.path
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
    "${local.state.redis.service_vip}"    = local.state.vault_pki.pki_configuration.dependency_roles["gitlab-redis-dep"].allowed_domains[0]
    "${local.state.postgres.service_vip}" = local.state.vault_pki.pki_configuration.dependency_roles["gitlab-postgres-dep"].allowed_domains[0]
    "${local.state.minio.service_vip}"    = local.state.vault_pki.pki_configuration.dependency_roles["gitlab-minio-dep"].allowed_domains[0]
  }
}
