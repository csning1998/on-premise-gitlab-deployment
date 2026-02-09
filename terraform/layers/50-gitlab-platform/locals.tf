
# Provider Configuration (Restored)
locals {
  kubeconfig   = yamldecode(data.terraform_remote_state.kubeadm_provision.outputs.kubeconfig_content)
  cluster_info = local.kubeconfig.clusters[0].cluster
  user_info    = local.kubeconfig.users[0].user

  k8s_provider_auth = {
    host                   = local.cluster_info.server
    cluster_ca_certificate = base64decode(local.cluster_info["certificate-authority-data"])
    client_certificate     = base64decode(local.user_info["client-certificate-data"])
    client_key             = base64decode(local.user_info["client-key-data"])
  }
}

# for platform-trust-engine module
locals {
  # K8s API Endpoint for Vault Callback
  k8s_api_endpoint = "https://${data.terraform_remote_state.kubeadm_provision.outputs.gitlab_kubeadm_virtual_ip}:6443"

  # Cluster CA from ConfigMap
  k8s_cluster_ca = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]

  # Vault Address
  vault_address     = "https://${data.terraform_remote_state.vault_pki.outputs.vault_ha_virtual_ip}:443"
  vault_policy_name = "${local.vault_role_name}-pki-policy"
  vault_ca_cert     = data.terraform_remote_state.vault_pki.outputs.vault_certificates.ca_cert.ca_cert
  vault_pki_path    = data.terraform_remote_state.vault_pki.outputs.pki_configuration.path
  vault_role_name   = data.terraform_remote_state.vault_pki.outputs.pki_configuration.component_roles["gitlab-frontend"].name
  vault_auth_path   = data.terraform_remote_state.vault_pki.outputs.auth_backend_paths["kubernetes"]
  # where `vault_auth_path` automatically fetch Auth Path (default is kubernetes, can be retrieved from map if changed).
}

# DNS Configuration
locals {
  dns_hosts = {
    # For Gitlab and Vault ingress VIP, respectively.
    "${data.terraform_remote_state.kubeadm_provision.outputs.gitlab_kubeadm_virtual_ip}" = "gitlab.iac.local"
    "${data.terraform_remote_state.vault_pki.outputs.vault_ha_virtual_ip}"               = "vault.iac.local"

    # For dependency roles.
    "${data.terraform_remote_state.redis.outputs.gitlab_redis_virtual_ip}"       = data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["gitlab-redis"].allowed_domains[0]
    "${data.terraform_remote_state.postgres.outputs.gitlab_postgres_virtual_ip}" = data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["gitlab-postgres"].allowed_domains[0]
    "${data.terraform_remote_state.minio.outputs.gitlab_minio_virtual_ip}"       = data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["gitlab-minio"].allowed_domains[0]
  }
}
