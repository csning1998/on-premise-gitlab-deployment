
# Provider Configuration (Restored)
locals {
  kubeconfig   = yamldecode(data.terraform_remote_state.microk8s_provision.outputs.kubeconfig_content)
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

  harbor_hostname = data.terraform_remote_state.vault_pki.outputs.pki_configuration.component_roles["harbor-frontend"].allowed_domains[0]

  # K8s API Endpoint for Vault Callback
  k8s_api_endpoint = "https://${data.terraform_remote_state.microk8s_provision.outputs.harbor_microk8s_ip_list[0]}:${var.microk8s_api_port}"

  # Cluster CA from ConfigMap
  k8s_cluster_ca = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]

  # Vault Address
  vault_address   = "https://${data.terraform_remote_state.vault_pki.outputs.vault_ha_virtual_ip}:443"
  vault_ca_cert   = data.terraform_remote_state.vault_pki.outputs.vault_certificates.ca_cert.ca_cert
  vault_pki_path  = data.terraform_remote_state.vault_pki.outputs.pki_configuration.path
  vault_role_name = data.terraform_remote_state.vault_pki.outputs.pki_configuration.component_roles["harbor-frontend"].name
  vault_auth_path = data.terraform_remote_state.vault_pki.outputs.auth_backend_paths["kubernetes"]
  # where `vault_auth_path` automatically fetch Auth Path (default is kubernetes, can be retrieved from map if changed).

  vault_policy_name = "${local.vault_role_name}-pki-policy"
}

# Vault Generic Secrets
locals {
  pg_superuser_password = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
  harbor_pg_db_password = data.vault_generic_secret.harbor_vars.data["harbor_pg_db_password"]
  harbor_admin_password = data.vault_generic_secret.harbor_vars.data["harbor_admin_password"]
}

# DNS Configuration
locals {
  dns_hosts = {
    # For Harbor and Vault ingress VIP, respectively.
    "${data.terraform_remote_state.microk8s_provision.outputs.harbor_microk8s_virtual_ip}" = "harbor.iac.local notary.harbor.iac.local"
    "${data.terraform_remote_state.vault_pki.outputs.vault_ha_virtual_ip}"                 = "vault.iac.local"

    # For dependency roles.
    "${data.terraform_remote_state.redis.outputs.harbor_redis_virtual_ip}"       = data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["harbor-redis"].allowed_domains[0]
    "${data.terraform_remote_state.postgres.outputs.harbor_postgres_virtual_ip}" = data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["harbor-postgres"].allowed_domains[0]
    "${data.terraform_remote_state.minio.outputs.harbor_minio_virtual_ip}"       = data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["harbor-minio"].allowed_domains[0]
  }
}
