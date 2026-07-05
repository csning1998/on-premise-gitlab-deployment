
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
    vault_frontend          = data.terraform_remote_state.vault_frontend.outputs
    vault_pki               = data.terraform_remote_state.vault_pki.outputs
    vault_prod_bootstrap    = data.terraform_remote_state.vault_prod_bootstrap.outputs
    runner_cluster          = data.terraform_remote_state.runner_cluster.outputs
    harbor_bootstrapper_oci = data.terraform_remote_state.harbor_bootstrapper_oci.outputs
    gitlab_frontend         = data.terraform_remote_state.gitlab_frontend.outputs
    harbor_frontend         = data.terraform_remote_state.harbor_frontend.outputs
    postgres                = data.terraform_remote_state.postgres.outputs
    redis                   = data.terraform_remote_state.redis.outputs
    minio                   = data.terraform_remote_state.minio.outputs
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
  pod_network_mtu = local.state.runner_cluster.global_network_mtu

  fqdn_gitlab              = local.state.vault_pki.global_pki_map["gitlab-frontend"].dns_san[0]
  fqdn_vault               = local.state.vault_pki.global_pki_map["vault-frontend"].dns_san[0]
  fqdn_harbor_bootstrapper = local.state.vault_pki.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  fqdn_harbor              = local.state.vault_pki.global_pki_map["harbor-frontend"].dns_san[0]
  fqdn_minio               = local.state.vault_pki.global_pki_map["gitlab-minio"].dns_san[0]
  fqdn_postgres            = local.state.vault_pki.global_pki_map["gitlab-postgres"].dns_san[0]
  fqdn_redis               = local.state.vault_pki.global_pki_map["gitlab-redis"].dns_san[0]

  harbor_registry     = local.fqdn_harbor_bootstrapper
  harbor_quay_proxy   = local.state.harbor_bootstrapper_oci.proxy_caches["quay_io"].project_name
  harbor_k8s_proxy    = local.state.harbor_bootstrapper_oci.proxy_caches["k8s_io"].project_name
  harbor_docker_proxy = local.state.harbor_bootstrapper_oci.proxy_caches["docker_hub"].project_name
  helm_chart_project  = local.state.harbor_bootstrapper_oci.proxy_oci["helm_charts"].name

  api_port     = local.state.runner_cluster.k8s_api_port
  api_endpoint = "https://${element(local.state.runner_cluster.runner_microk8s_ip_list, 0)}:${local.api_port}"

  cluster_ca = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]

  vault_api_port = local.state.vault_frontend.vault_api_port
  vault_address  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_ca_cert  = base64decode(local.state.vault_pki.bootstrap_ca_b64.content_b64)
  vault_pki_path = local.state.vault_pki.pki_configuration.path

  vault_role_name = local.state.vault_pki.global_pki_map["gitlab-runner"].role_name
  vault_auth_path = local.state.vault_pki.global_pki_map["gitlab-runner"].auth_config.path
}

# 4. DNS Configuration
locals {
  vip_gitlab        = local.state.gitlab_frontend.service_vip
  vip_vault         = local.state.vault_pki.vault_service_vip
  vip_redis         = local.state.redis.connection_info.host
  vip_postgres      = local.state.postgres.connection_info.host
  vip_minio         = local.state.minio.connection_info.host
  vip_harbor        = local.state.harbor_frontend.harbor_microk8s_virtual_ip
  vip_observability = data.terraform_remote_state.observability_infra.outputs.observability_microk8s_virtual_ip

  mimir_fqdn = [for san in local.state.vault_pki.global_pki_map["observability-frontend"].dns_san : san if startswith(san, "mimir.")][0]

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
