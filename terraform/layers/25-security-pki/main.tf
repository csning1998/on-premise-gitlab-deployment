
# Persist the PKI CA Certificate for Dependent Layers (e.g. Minio Provider)
resource "local_file" "pki_root_ca" {
  content  = module.vault_pki_setup.pki_root_ca_certificate
  filename = abspath("${path.module}/tls/pki-root-ca.crt")
}

module "vault_pki_setup" {
  source = "../../modules/configuration/vault-pki-setup"
  providers = {
    vault = vault.production
  }

  vault_addr          = local.sys_vault_addr
  root_domain         = local.root_domain
  root_ca_common_name = local.root_ca_common_name
  pki_roles           = local.all_roles
  pki_engine_config   = var.vault_pki_engine_config
}

# 1. Workload Identities for AppRole (Dependencies / Baremetal)
module "vault_workload_identity_approle" {
  source = "../../modules/configuration/vault-workload-identity"
  providers = {
    vault = vault.production
  }
  depends_on = [module.vault_pki_setup]

  for_each           = local.all_roles
  name               = each.key
  vault_role_name    = each.value.name
  approle_mount_path = each.value.approle_path
  pki_mount_path     = module.vault_pki_setup.vault_pki_path
  extra_policy_hcl   = lookup(local.workload_identity_extra_rules, each.key, {})
}

# 2. Workload Identities for Kubernetes (Components / Addons)
resource "vault_policy" "kubernetes_policy" {
  provider = vault.production
  for_each = local.kubernetes_roles
  name     = "${each.key}-policy"
  policy = jsonencode({
    path = merge(
      {
        "${module.vault_pki_setup.vault_pki_path}/issue/${each.value.name}" = { capabilities = ["create", "update"] },
        "${module.vault_pki_setup.vault_pki_path}/sign/${each.value.name}"  = { capabilities = ["create", "update"] }
      },
      lookup(local.workload_identity_extra_rules, each.key, {})
    )
  })
}

resource "vault_kubernetes_auth_backend_role" "kubernetes_role" {
  provider  = vault.production
  for_each  = local.kubernetes_roles
  backend   = module.vault_pki_setup.auth_backend_paths[each.value.auth_path]
  role_name = each.value.name

  # Allow all service accounts in all namespaces within the specific cluster-auth mount
  # This matches the dynamic nature of the metadata-driven auth backends
  bound_service_account_names      = ["*"]
  bound_service_account_namespaces = ["*"]

  token_policies = [
    "default",
    vault_policy.kubernetes_policy[each.key].name,
    "${each.value.name}-pki-policy"
  ]
}
