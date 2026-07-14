
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
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    credentials          = data.terraform_remote_state.credentials.outputs
    harbor_bootstrapper  = data.terraform_remote_state.harbor_bootstrapper.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    provision_databases  = data.terraform_remote_state.provision_databases.outputs
    provision            = data.terraform_remote_state.provision.outputs
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
    hostname             = local.gitlab_frontend_fqdn
    edition              = "ce"
    dns_sans             = local.state.vault_pki.global_pki_map["gitlab-frontend"].dns_san
    omniauth_secret_name = kubernetes_secret.gitlab_keycloak_oidc.metadata[0].name
    rails_secret_name    = "gitlab-rails-secret"
  }
}

# 3. Application Endpoint Context
locals {
  # FQDNs
  gitlab_frontend_fqdn     = local.state.vault_pki.global_pki_map["gitlab-frontend"].dns_san[0]
  vault_fqdn               = local.state.vault_pki.global_pki_map["vault-frontend"].dns_san[0]
  harbor_bootstrapper_fqdn = local.state.vault_pki.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  harbor_frontend_fqdn     = local.state.vault_pki.global_pki_map["harbor-frontend"].dns_san[0]
  minio_fqdn               = local.state.vault_pki.global_pki_map["gitlab-minio"].dns_san[0]
  postgres_fqdn            = local.state.vault_pki.global_pki_map["gitlab-postgres"].dns_san[0]
  redis_fqdn               = local.state.vault_pki.global_pki_map["gitlab-redis"].dns_san[0]

  # Harbor Bootstrapper (Registry Redirection)
  harbor_registry     = local.harbor_bootstrapper_fqdn
  harbor_docker_proxy = local.state.harbor_bootstrapper.proxy_caches.docker_hub.project_name
  harbor_gitlab_proxy = local.state.harbor_bootstrapper.proxy_caches.gitlab_com.project_name
  harbor_k8s_proxy    = local.state.harbor_bootstrapper.proxy_caches.k8s_io.project_name
  helm_chart_project  = local.state.harbor_bootstrapper.proxy_oci.helm_charts.name

  # GitLab CNG image registry and repository routed through Harbor Bootstrapper proxy
  gitlab_image_registry   = local.harbor_registry
  gitlab_image_repository = "${local.harbor_gitlab_proxy}/gitlab-org/build/cng"

  # Cluster CA from ConfigMap
  cluster_ca  = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]
  postgres_ca = "gitlab-postgres-tls"

  # Vault Connection (Standardized)
  vault_api_port          = local.state.provision.network_context.vault_api_port
  vault_endpoint          = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_pki_path          = local.state.vault_pki.pki_configuration.path
  vault_pki_lease_default = local.state.vault_pki.pki_configuration.lease_durations.default
  vault_pki_lease_agent   = local.state.vault_pki.pki_configuration.lease_durations.agent
}

# 4. External Service Address & Ports
locals {
  # Dynamic Ports/VIPs from Layer 10 (Shared Load Balancer)
  redis_port = local.state.provision_databases.redis_connection_info.port
  minio_port = local.state.provision_databases.minio_connection_info.port
  shell_port = local.state.provision.network_context.gitlab_ssh_port

  # VIPs from LB Infrastructure
  minio_address = "https://${local.minio_fqdn}:${local.minio_port}"

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
      "ca-bootstrap.crt"    = base64decode(local.state.vault_pki.global_vault_pki_b64.ca_cert_b64)
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

  has_praefect    = local.state.provision.has_praefect
  gitaly_endpoint = local.state.provision.gitaly_endpoint

  gitlab_reloader_annotations = {
    global = {
      registry = {
        enabled = true
        host    = local.harbor_frontend_fqdn
        port    = 443
        api = {
          protocol = "https"
          host     = local.harbor_frontend_fqdn
          port     = 443
        }
        certificate = {
          secret = "gitlab-registry-token-cert"
        }
      }
    }
    registry = {
      enabled  = false
      host     = local.harbor_frontend_fqdn
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

locals {
  credential_paths = local.state.credentials.global_credential_paths
}

# 8. Observability Endpoint Context
locals {
  mimir_fqdn             = [for san in local.state.vault_pki.global_pki_map["observability-frontend"].dns_san : san if startswith(san, "mimir.")][0]
  mimir_remote_write_url = "https://${local.mimir_fqdn}/api/v1/push"
  mimir_tenant_id        = "gitlab"

  loki_fqdn     = [for san in local.state.vault_pki.global_pki_map["observability-frontend"].dns_san : san if startswith(san, "loki.")][0]
  loki_push_url = "https://${local.loki_fqdn}/loki/api/v1/push"

  postgres_exporter_port = local.state.provision_databases.observability_targets.postgres_exporter_port
  redis_exporter_port    = local.state.provision_databases.observability_targets.redis_exporter_port
  etcd_client_port       = local.state.provision_databases.observability_targets.etcd_client_port
  minio_metrics_port     = local.state.provision_databases.observability_targets.minio_metrics_port
  # MinIO serves Prometheus metrics on the same API port (9000); there is no separate metrics port.

  postgres_vip = local.state.provision_databases.postgres_connection_info.host
  redis_vip    = local.state.provision_databases.redis_connection_info.host
  minio_vip    = local.state.provision_databases.minio_connection_info.host
  etcd_ips     = local.state.provision_databases.observability_targets.etcd_ips

  gitaly_metrics_port          = local.state.provision.gitaly_observability_targets.gitaly_metrics_port
  praefect_metrics_port        = local.state.provision.gitaly_observability_targets.praefect_metrics_port
  praefect_patroni_pg_exp_port = local.state.provision.gitaly_observability_targets.praefect_patroni_metrics_port
  praefect_patroni_etcd_port   = local.state.provision.gitaly_observability_targets.praefect_patroni_etcd_port

  gitaly_ips           = local.state.provision.gitaly_observability_targets.gitaly_node_ips
  praefect_ips         = local.state.provision.gitaly_observability_targets.praefect_node_ips
  praefect_patroni_ips = local.state.provision.gitaly_observability_targets.praefect_patroni_node_ips
}

# 9. Node Exporter Context
locals {
  node_exporter_port = local.state.provision.kubeadm_node_exporter_targets.port
  node_exporter_ip_groups = {
    postgres         = local.state.provision_databases.observability_targets.postgres_ips
    redis            = local.state.provision_databases.observability_targets.redis_ips
    minio            = local.state.provision_databases.observability_targets.minio_ips
    etcd             = local.etcd_ips
    gitaly           = local.gitaly_ips
    praefect         = local.has_praefect ? local.praefect_ips : []
    praefect-patroni = local.has_praefect ? local.praefect_patroni_ips : []
    kubeadm          = local.state.provision.kubeadm_node_exporter_targets.ips
  }
}
