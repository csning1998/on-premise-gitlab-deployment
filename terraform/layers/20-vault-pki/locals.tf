
# 1. Global Topology and Bootstrap CA.
locals {
  global_topology     = data.terraform_remote_state.topology.outputs
  root_domain         = local.global_topology.domain_suffix
  root_ca_common_name = local.global_topology.pki_settings.root_ca_common_name
  root_ca_pem         = base64decode(data.terraform_remote_state.topology.outputs.vault_pki.ca_cert)
}

resource "local_file" "bootstrap_ca" {
  content  = local.root_ca_pem
  filename = "${path.root}/../10-vault-raft/tls/bootstrap-ca.crt"
}

# 2. TTL Policy for different environments
locals {
  ttl_policy = {
    "production"  = { max = 60 * 60 * 24 * 365, default = 60 * 60 * 24 * 30 } # Max 1 Year, Default 30 Days
    "staging"     = { max = 60 * 60 * 24 * 30, default = 60 * 60 * 24 * 7 }   # Max 30 Days, Default 7 Days
    "development" = { max = 60 * 60 * 24 * 7, default = 60 * 60 * 24 }        # Max 1 Day,   Default 1 Hour
    "default"     = { max = 60 * 60 * 24, default = 60 * 60 }                 # Fallback
  }
}

# 3. Generate Vault Roles (Based on SSoT pki_map)
#    a. Map domains from Global Topology
#    b. Inject Metadata (OU)
#    c. Apply TTL Policy
locals {
  # Component Roles (Server Certs): 
  component_roles = {
    for k, v in local.global_topology.pki_map : k => {
      name            = v.role_name
      allowed_domains = v.dns_san
      ou              = v.ou
      max_ttl         = lookup(local.ttl_policy, v.ttl_stage, local.ttl_policy["default"]).max
      ttl             = lookup(local.ttl_policy, v.ttl_stage, local.ttl_policy["default"]).default
    }
    if !endswith(k, "-dep")
  }

  # Dependency Roles (Client Certs / Auth): 
  dependency_roles = {
    for k, v in local.global_topology.pki_map : k => {
      name            = v.role_name
      allowed_domains = v.dns_san
      ou              = v.ou
      max_ttl         = lookup(local.ttl_policy, v.ttl_stage, local.ttl_policy["default"]).max
      ttl             = lookup(local.ttl_policy, v.ttl_stage, local.ttl_policy["default"]).default
    }
    if endswith(k, "-dep")
  }
}

# 6. Specific Vault Policy for some Workload Identity: 
#    Key must correspond to service_catalog of "${service_name}-${component_name}"
locals {
  workload_identity_extra_policies = {
    "bootstrap-harbor-frontend" = <<EOT
# Allow reading Harbor related App Secrets (KV v2)
path "secret/data/on-premise-gitlab-deployment/dev-harbor/*" {
  capabilities = ["read"]
}
EOT

    "harbor-frontend" = <<EOT
# Allow uploading Harbor MicroK8s Kubeconfig to Vault (KV v2)
path "secret/data/on-premise-gitlab-deployment/infrastructure/kubeconfig/harbor" {
  capabilities = ["create", "update", "read"]
}
EOT

    "gitlab-frontend" = <<EOT
# Allow uploading GitLab Kubeadm Kubeconfig to Vault (KV v2)
path "secret/data/on-premise-gitlab-deployment/infrastructure/kubeconfig/gitlab" {
  capabilities = ["create", "update", "read"]
}
EOT
  }
}
