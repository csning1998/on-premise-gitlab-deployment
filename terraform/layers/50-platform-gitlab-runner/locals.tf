
# 1. External State Context
locals {
  state = {
    metadata                = data.terraform_remote_state.metadata.outputs
    vault_pki               = data.terraform_remote_state.vault_pki.outputs
    vault_prod_bootstrap    = data.terraform_remote_state.vault_prod_bootstrap.outputs
    gitlab_frontend         = data.terraform_remote_state.gitlab_frontend.outputs
    runner_cluster          = data.terraform_remote_state.runner_cluster.outputs
    harbor_bootstrapper     = data.terraform_remote_state.harbor_bootstrapper.outputs
    harbor_bootstrapper_oci = data.terraform_remote_state.harbor_bootstrapper_oci.outputs
  }
}

# 2. K8s Provider Authentication Context (Lossless from L50 GitLab)
locals {
  kubeconfig_raw = yamldecode(base64decode(data.vault_kv_secret_v2.kubeconfig.data["content_b64"]))
  cluster_info   = local.kubeconfig_raw.clusters[0].cluster
  user_info      = local.kubeconfig_raw.users[0].user

  api_server_connection = {
    host               = local.cluster_info.server
    ca_cert            = base64decode(local.cluster_info["certificate-authority-data"])
    client_certificate = base64decode(local.user_info["client-certificate-data"])
    client_key         = base64decode(local.user_info["client-key-data"])
  }
}

# 3. Trust Engine & Infrastructure Context
locals {
  # OCI & Harbor Context
  harbor_registry     = local.state.harbor_bootstrapper.bstrap_harbor_fqdn
  harbor_quay_proxy   = local.state.harbor_bootstrapper_oci.proxy_caches["quay_io"].project_name
  harbor_k8s_proxy    = local.state.harbor_bootstrapper_oci.proxy_caches["k8s_io"].project_name
  harbor_docker_proxy = local.state.harbor_bootstrapper_oci.proxy_caches["docker_hub"].project_name
  helm_chart_project  = "helm-charts"

  # API Endpoint for Vault Callback
  api_port     = local.state.metadata.global_topology_network["gitlab"]["runner"].ports["api-server"].frontend_port
  api_endpoint = "https://${local.state.runner_cluster.runner_microk8s_ip_list[0]}:${local.api_port}"

  # Cluster CA from ConfigMap (SSoT for K8s API verification)
  cluster_ca = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]

  # Vault Connection (Standardized)
  vault_api_port = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
  vault_address  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_ca_cert  = local.state.vault_pki.bootstrap_ca.content
  vault_pki_path = local.state.vault_pki.pki_configuration.path

  # Map to the specific component identity in Vault PKI
  vault_role_name   = local.state.metadata.global_pki_map["gitlab-runner"].role_name
  vault_auth_path   = local.state.metadata.global_pki_map["gitlab-runner"].auth_config.path
  vault_policy_name = "${local.vault_role_name}-pki-policy"
}

# 4. CA Bundle for Runner Trust
locals {
  ca_bundle_config = {
    name        = "gitlab-ca-bundle"
    secret_name = "gitlab-ca-bundle"

    content = join("\n", [
      base64decode(local.state.vault_pki.pki_configuration.ca_cert),
      base64decode(local.state.vault_pki.bootstrap_ca.content)
    ])
  }
}
