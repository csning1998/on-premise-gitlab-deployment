
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_creds   = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_creds.username
    password = local._gl_creds.token
  }
}

# 1. External State Context
locals {
  state = {
    metadata                = data.terraform_remote_state.metadata.outputs
    network                 = data.terraform_remote_state.network.outputs
    vault_pki               = data.terraform_remote_state.vault_pki.outputs
    vault_prod_bootstrap    = data.terraform_remote_state.vault_prod_bootstrap.outputs
    runner_cluster          = data.terraform_remote_state.runner_cluster.outputs
    harbor_bootstrapper_oci = data.terraform_remote_state.harbor_bootstrapper_oci.outputs
  }
}

# 2. K8s Provider Authentication Context
locals {
  kubeconfig_raw = yamldecode(base64decode(ephemeral.vault_kv_secret_v2.kubeconfig.data["content_b64"]))
  cluster_info   = element(local.kubeconfig_raw.clusters, 0).cluster
  user_info      = element(local.kubeconfig_raw.users, 0).user

  api_server_connection = {
    host               = local.cluster_info.server
    ca_cert            = base64decode(local.cluster_info["certificate-authority-data"])
    client_certificate = base64decode(local.user_info["client-certificate-data"])
    client_key         = base64decode(local.user_info["client-key-data"])
  }

  issuer_name = module.platform_trust_engine.issuer_name
  issuer_kind = module.platform_trust_engine.issuer_kind
}

# 3. Trust Engine & Infrastructure Context
locals {
  pod_network_mtu = local.state.metadata.global_network_baseline.global_mtu

  fqdn_gitlab              = local.state.metadata.global_pki_map["gitlab-frontend"].dns_san[0]
  fqdn_vault               = local.state.metadata.global_pki_map["vault-frontend"].dns_san[0]
  fqdn_harbor_bootstrapper = local.state.metadata.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  fqdn_harbor              = local.state.metadata.global_pki_map["harbor-frontend"].dns_san[0]
  fqdn_minio               = local.state.metadata.global_pki_map["gitlab-minio"].dns_san[0]
  fqdn_postgres            = local.state.metadata.global_pki_map["gitlab-postgres"].dns_san[0]
  fqdn_redis               = local.state.metadata.global_pki_map["gitlab-redis"].dns_san[0]

  harbor_registry     = local.fqdn_harbor_bootstrapper
  harbor_quay_proxy   = local.state.harbor_bootstrapper_oci.proxy_caches["quay_io"].project_name
  harbor_k8s_proxy    = local.state.harbor_bootstrapper_oci.proxy_caches["k8s_io"].project_name
  harbor_docker_proxy = local.state.harbor_bootstrapper_oci.proxy_caches["docker_hub"].project_name
  helm_chart_project  = local.state.harbor_bootstrapper_oci.proxy_oci["helm_charts"].name

  api_port     = local.state.metadata.global_topology_network["gitlab"]["runner"].ports["api-server"].frontend_port
  api_endpoint = "https://${element(local.state.runner_cluster.runner_microk8s_ip_list, 0)}:${local.api_port}"

  cluster_ca = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]

  vault_api_port = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
  vault_address  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_ca_cert  = base64decode(local.state.vault_pki.bootstrap_ca_b64.content_b64)
  vault_pki_path = local.state.vault_pki.pki_configuration.path

  vault_role_name = local.state.metadata.global_pki_map["gitlab-runner"].role_name
  vault_auth_path = local.state.metadata.global_pki_map["gitlab-runner"].auth_config.path
}

# 4. DNS Configuration
locals {
  vip_gitlab        = local.state.network.infrastructure_map["core-gitlab-frontend"].lb_config.vip
  vip_vault         = local.state.vault_pki.vault_service_vip
  vip_redis         = local.state.network.infrastructure_map["core-gitlab-redis"].lb_config.vip
  vip_postgres      = local.state.network.infrastructure_map["core-gitlab-postgres"].lb_config.vip
  vip_minio         = local.state.network.infrastructure_map["core-gitlab-minio"].lb_config.vip
  vip_harbor        = local.state.network.infrastructure_map["core-harbor-frontend"].lb_config.vip
  vip_observability = data.terraform_remote_state.observability_infra.outputs.observability_microk8s_virtual_ip

  mimir_fqdn = [for san in local.state.metadata.global_pki_map["observability-frontend"].dns_san : san if startswith(san, "mimir.")][0]

  dns_hosts = {
    "${local.vip_gitlab}"        = local.fqdn_gitlab
    "${local.vip_vault}"         = local.fqdn_vault
    "${local.vip_redis}"         = local.fqdn_redis
    "${local.vip_postgres}"      = local.fqdn_postgres
    "${local.vip_minio}"         = local.fqdn_minio
    "${local.vip_harbor}"        = local.fqdn_harbor
    "${local.vip_observability}" = local.mimir_fqdn
  }
}
