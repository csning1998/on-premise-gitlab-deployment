
resource "local_file" "trust_bundle" {
  content  = <<EOT
${chomp(local.bootstrap_ca_chain_pem)}
${chomp(base64decode(module.vault_pki_setup.pki_intermediate_ca_certificate_b64))}
EOT
  filename = abspath("${path.module}/tls/trust-bundle.crt")
}

module "vault_pki_setup" {
  source = "../../modules/configuration/vault-pki-setup"
  providers = {
    vault.production = vault.production
    vault.bootstrap  = vault.bootstrap
  }

  vault_endpoint                    = local.sys_vault_endpoint
  pki_settings                      = local.state.metadata.global_pki_config
  pki_roles                         = local.all_roles
  pki_engine_config                 = var.vault_pki_engine_config
  bootstrap_pki_mount_path          = local.state.vault_bootstrapper.bootstrap_pki_mount_path
  bootstrap_root_ca_certificate_pem = local.state.vault_bootstrapper.bootstrap_root_ca_certificate_pem
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
  approle_mount_path = module.vault_pki_setup.auth_backend_paths["approle"]
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

  # Restrict to component-specific namespace and ServiceAccounts. "observability" is included
  # because every tenant cluster runs its own Alloy in a namespace of that name, which is
  # separate from the component-prefixed namespace.
  bound_service_account_names      = [each.key, "vault-issuer", "default"]
  bound_service_account_namespaces = [split("-", each.key)[0], "cert-manager", "default", "observability"]

  token_policies = [
    "default",
    vault_policy.kubernetes_policy[each.key].name,
    "${each.value.name}-pki-policy"
  ]
}
