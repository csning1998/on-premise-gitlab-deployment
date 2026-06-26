
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
    metadata             = data.terraform_remote_state.metadata.outputs
    network              = data.terraform_remote_state.network.outputs.infrastructure_map
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    redis                = data.terraform_remote_state.redis.outputs
    postgres             = data.terraform_remote_state.postgres.outputs
    minio                = data.terraform_remote_state.minio.outputs
    kubeadm              = data.terraform_remote_state.kubeadm.outputs
    harbor_bootstrapper  = data.terraform_remote_state.harbor_bootstrapper.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    provision_databases  = data.terraform_remote_state.provision_databases.outputs
    provision            = data.terraform_remote_state.provision.outputs
    harbor               = data.terraform_remote_state.harbor.outputs
    gitaly_praefect      = data.terraform_remote_state.gitaly_praefect.outputs
  }
}

# 2. K8s Provider Authentication Context
locals {
  kubeconfig   = yamldecode(base64decode(ephemeral.vault_kv_secret_v2.kubeconfig.data["content_b64"]))
  cluster_info = local.kubeconfig.clusters[0].cluster
  user_info    = local.kubeconfig.users[0].user

  api_server_connection = {
    host               = local.cluster_info.server
    ca_cert            = base64decode(local.cluster_info["certificate-authority-data"])
    client_certificate = base64decode(local.user_info["client-certificate-data"])
    client_key         = base64decode(local.user_info["client-key-data"])
  }

  # Trust Engine Contract (Sourced from Provisioning Layer 40)
  issuer_name = local.state.provision.issuer_name
  issuer_kind = local.state.provision.issuer_kind

  # GitLab Application Configuration
  gitlab_config = {
    hostname             = local.fqdn_gitlab
    edition              = "ce"
    dns_sans             = local.state.metadata.global_pki_map["gitlab-frontend"].dns_san
    omniauth_secret_name = kubernetes_secret.gitlab_keycloak_oidc.metadata[0].name
    rails_secret_name    = "gitlab-rails-secret"
  }
}

# 3. Application Endpoint Context
locals {
  # FQDNs
  fqdn_gitlab              = local.state.metadata.global_pki_map["gitlab-frontend"].dns_san[0]
  fqdn_vault               = local.state.metadata.global_pki_map["vault-frontend"].dns_san[0]
  fqdn_harbor_bootstrapper = local.state.metadata.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  fqdn_harbor              = local.state.metadata.global_pki_map["harbor-frontend"].dns_san[0]
  fqdn_minio               = local.state.metadata.global_pki_map["gitlab-minio"].dns_san[0]
  fqdn_postgres            = local.state.metadata.global_pki_map["gitlab-postgres"].dns_san[0]
  fqdn_redis               = local.state.metadata.global_pki_map["gitlab-redis"].dns_san[0]

  # Harbor Bootstrapper (Registry Redirection)
  harbor_registry     = local.fqdn_harbor_bootstrapper
  harbor_docker_proxy = local.state.harbor_bootstrapper.proxy_caches.docker_hub.project_name
  harbor_gitlab_proxy = local.state.harbor_bootstrapper.proxy_caches.gitlab_com.project_name
  helm_chart_project  = local.state.harbor_bootstrapper.proxy_oci.helm_charts.name

  # GitLab CNG image registry and repository routed through Harbor Bootstrapper proxy
  gitlab_image_registry   = local.harbor_registry
  gitlab_image_repository = "${local.harbor_gitlab_proxy}/gitlab-org/build/cng"

  # Cluster CA from ConfigMap
  cluster_ca  = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]
  postgres_ca = "gitlab-postgres-tls"

  # Vault Connection (Standardized)
  vault_address           = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_api_port          = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
  vault_pki_path          = local.state.vault_pki.pki_configuration.path
  vault_pki_lease_default = local.state.vault_pki.pki_configuration.lease_durations.default
  vault_pki_lease_agent   = local.state.vault_pki.pki_configuration.lease_durations.agent
}

# 4. External Service Address & Ports
locals {
  # Dynamic Ports/VIPs from Layer 10 (Shared Load Balancer)
  redis_port = local.state.network["core-gitlab-redis"].lb_config.ports["main"].frontend_port
  minio_port = local.state.network["core-gitlab-minio"].lb_config.ports["api"].frontend_port
  shell_port = local.state.network["core-gitlab-frontend"].lb_config.ports["gitlab-ssh"].frontend_port

  # VIPs from LB Infrastructure
  minio_address = "https://${local.fqdn_minio}:${local.minio_port}"

  # GitLab Application Database Context
  gitlab_db = {
    username = data.vault_kv_secret_v2.gitlab_app_database.data["username"]
    password = data.vault_kv_secret_v2.gitlab_app_database.data["password"]
    database = data.vault_kv_secret_v2.gitlab_app_database.data["database"]
    host     = data.vault_kv_secret_v2.gitlab_app_database.data["host"]
    port     = tonumber(data.vault_kv_secret_v2.gitlab_app_database.data["port"])
  }

  # Infrastructure Credentials discovered from vault
  redis_password = data.vault_kv_secret_v2.db_vars.data["redis_requirepass"]
}

# 5. CA Bundle Configuration
locals {
  ca_bundle_config = {
    name        = "gitlab-ca-bundle"
    secret_name = "gitlab-ca-bundle"

    # One key per CA so update-ca-certificates processes each file individually.
    # All three CAs are already available from upstream remote state — no local file needed.
    certs = {
      "ca-bootstrap.crt"    = base64decode(local.state.metadata.global_vault_pki_b64.ca_cert_b64)
      "ca-root.crt"         = base64decode(local.state.vault_pki.pki_configuration.root_ca_certificate_b64)
      "ca-intermediate.crt" = base64decode(local.state.vault_pki.pki_configuration.intermediate_ca_certificate_b64)
    }
  }
}

# 6. Object Storage Mappings
locals {
  s3_region          = "us-east-1"
  minio_function_map = local.state.provision_databases.minio_function_map
}

# 7. Reloader Configuration (Platform Level)
locals {
  reloader_oci_config = {
    repository = "oci://${local.harbor_registry}/${local.helm_chart_project}"
  }

  # Internal helper for reloader annotations to avoid duplication across components
  _gitlab_reloader_common = {
    deployment = {
      annotations = {
        "reloader.stakater.com/auto"          = "true"
        "secret.reloader.stakater.com/reload" = local.postgres_ca
      }
    }
  }

  # Detect Gitaly endpoint automatically depending on whether Praefect cluster nodes are provisioned in the remote state
  has_praefect    = length([for name, node in local.state.gitaly_praefect.topology_cluster : name if length(regexall("praefect", name)) > 0]) > 0
  gitaly_endpoint = local.has_praefect ? "${local.state.network["core-gitlab-praefect"].lb_config.vip}:2305" : "${local.state.network["core-gitlab-gitaly"].lb_config.vip}:8075"

  gitlab_reloader_annotations = {
    global = {
      registry = {
        enabled = true
        host    = local.fqdn_harbor
        port    = 443
        api = {
          protocol = "https"
          host     = local.fqdn_harbor
          port     = 443
        }
        certificate = {
          secret = "gitlab-registry-token-cert"
        }
      }
    }
    registry = {
      enabled  = false
      host     = local.fqdn_harbor
      port     = 443
      tokenKey = "registry-auth.key"
      secret = {
        secret = "gitlab-registry-token-key"
      }
    }
    gitlab = {
      webservice = local._gitlab_reloader_common
      sidekiq    = local._gitlab_reloader_common
      gitlab-shell = {
        service = {
          type     = "NodePort"
          nodePort = 32022
        }
      }
    }
  }
}

# Credential path map alias derived from foundation metadata (L00 SSoT)
locals {
  credential_paths = data.terraform_remote_state.metadata.outputs.global_credential_paths
}

# 8. Observability Endpoint Context
locals {
  mimir_fqdn             = [for san in local.state.metadata.global_pki_map["observability-frontend"].dns_san : san if startswith(san, "mimir.")][0]
  mimir_remote_write_url = "https://${local.mimir_fqdn}/api/v1/push"

  port_postgres_exporter = local.state.metadata.global_topology_network["gitlab"]["postgres"].ports["metrics"].frontend_port
  port_redis_exporter    = local.state.metadata.global_topology_network["gitlab"]["redis"].ports["metrics"].frontend_port
  port_etcd_client       = local.state.metadata.global_topology_network["gitlab"]["etcd"].ports["client"].frontend_port
  port_minio_metrics     = local.state.metadata.global_topology_network["gitlab"]["minio"].ports["api"].frontend_port
  # MinIO serves Prometheus metrics on the same API port (9000); there is no separate metrics port.

  vip_postgres = local.state.postgres.service_vip
  vip_redis    = local.state.redis.service_vip
  vip_minio    = local.state.minio.service_vip
  etcd_ips     = local.state.metadata.global_topology_network["gitlab"]["etcd"].node_ips

  port_gitaly_metrics          = local.state.metadata.global_topology_network["gitlab"]["gitaly"].ports["metrics"].frontend_port
  port_praefect_metrics        = local.state.metadata.global_topology_network["gitlab"]["praefect"].ports["metrics"].frontend_port
  port_praefect_patroni_pg_exp = local.state.metadata.global_topology_network["gitlab"]["praefect-patroni"].ports["metrics"].frontend_port
  port_praefect_patroni_etcd   = local.state.metadata.global_topology_network["gitlab"]["praefect-patroni"].ports["etcd"].frontend_port

  gitaly_ips           = local.state.metadata.global_topology_network["gitlab"]["gitaly"].node_ips
  praefect_ips         = local.state.metadata.global_topology_network["gitlab"]["praefect"].node_ips
  praefect_patroni_ips = local.state.metadata.global_topology_network["gitlab"]["praefect-patroni"].node_ips
}
