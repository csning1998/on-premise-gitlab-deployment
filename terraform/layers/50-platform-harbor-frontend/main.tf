
# [REFACTORED] Trust Engine Integration
module "platform_trust_engine" {
  source = "../../modules/kubernetes-addons/platform-trust-engine"
  providers = {
    vault = vault.production
  }

  # 1. K8s Cluster Connection (for Vault to call back)
  api_server_connection = {
    host    = local.api_endpoint
    ca_cert = local.cluster_ca
  }

  # 2. Vault Connection (for Cert-Manager to authenticate)
  vault_config = {
    address   = local.vault_address
    ca_cert   = local.vault_ca_cert
    auth_path = local.vault_auth_path
  }

  # 3. Issuer Configuration (The "Contract" between K8s and Vault)
  issuer_config = {
    name            = var.trust_engine_config.issuer_name
    issue_path      = "sign"
    vault_role_name = local.vault_role_name
    pki_mount_path  = local.vault_pki_path
  }

  # 4. Reviewer Identity (The entity that validates tokens)
  reviewer_service_account = {
    name      = "vault-reviewer"
    namespace = "default"
  }

  # 5. Helm Chart Installation
  helm_config = {
    install          = true
    version          = var.cert_manager_config.version
    namespace        = var.cert_manager_config.namespace
    create_namespace = true
    image_registry   = local.harbor_registry
    image_repository = "${local.harbor_quay_proxy}/jetstack"
    chart_project    = local.helm_chart_project
  }
}

# Ingress Controller
module "ingress_controller" {
  source = "../../modules/kubernetes-addons/microk8s-ingress"

  ingress_vip        = data.terraform_remote_state.microk8s_provision.outputs.harbor_microk8s_virtual_ip
  ingress_class_name = "nginx"
  image_registry     = local.harbor_registry
  chart_project      = local.helm_chart_project
}

# CoreDNS Configuration
module "coredns_config" {
  source = "../../modules/kubernetes-addons/coredns-config"

  hosts = local.dns_hosts
}

module "reloader" {
  source            = "../../modules/kubernetes-addons/reloader"
  harbor_oci_config = local.reloader_oci_config
}

resource "kubernetes_namespace" "harbor" {
  metadata {
    name = "harbor"
  }
}

# For Harbor core secret key
resource "random_password" "harbor_core_secret_key" {
  length  = 32
  special = true
  upper   = true
}

module "harbor_core" {
  source = "../../modules/kubernetes-addons/helm-chart-harbor"

  ca_bundle = local.ca_bundle_config

  helm_config = {
    version        = var.harbor_helm_config.version
    namespace      = var.harbor_helm_config.namespace
    timeout        = 600
    image_registry = local.harbor_registry
    chart_project  = local.helm_chart_project
  }

  certificate_config = {
    duration     = local.state.vault_pki.pki_configuration.lease_durations.default
    renew_before = local.state.vault_pki.pki_configuration.lease_durations.agent
  }

  harbor_config = {
    hostname       = local.harbor_fqdn
    admin_password = local.harbor_admin_password
    notary_prefix  = var.harbor_helm_config.notary_prefix
    secret_key     = random_password.harbor_core_secret_key.result
    dns_sans       = local.state.metadata.global_pki_map["harbor-frontend"].dns_san
  }

  helm_values_override = local.harbor_reloader_annotations

  ingress_config = {
    class_name      = var.harbor_helm_config.ingress_class
    tls_secret_name = var.harbor_helm_config.tls_secret_name
    issuer_name     = var.trust_engine_config.issuer_name
    issuer_kind     = var.trust_engine_config.issuer_kind
  }

  external_services = {
    postgres = {
      host     = local.postgres_fqdn
      password = local.harbor_pg_db_password
      port     = local.pg_port
    }
    redis = {
      host     = local.redis_fqdn
      password = local.redis_password
    }
    s3 = {
      bucket     = var.object_storage_config.bucket_name
      region     = var.object_storage_config.region
      access_key = local.minio_access_key
      secret_key = local.minio_secret_key
      endpoint   = "https://${local.minio_fqdn}" # Harbor chart uses this
    }
  }

  depends_on = [
    module.platform_trust_engine,
    module.reloader
  ]
}
