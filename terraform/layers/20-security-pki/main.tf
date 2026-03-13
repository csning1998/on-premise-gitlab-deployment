
module "vault_pki_setup" {
  source = "../../modules/configuration/vault-pki-setup"
  providers = {
    vault = vault.production
  }

  vault_addr          = local.sys_vault_addr
  root_domain         = local.root_domain
  root_ca_common_name = local.root_ca_common_name

  auth_backends     = var.vault_auth_backends
  pki_engine_config = var.vault_pki_engine_config

  component_roles  = local.component_roles
  dependency_roles = local.dependency_roles
}

module "vault_workload_identity_components" {

  source     = "../../modules/configuration/vault-workload-identity"
  providers = {
    vault = vault.production
  }
  depends_on = [module.vault_pki_setup]

  for_each           = local.component_roles
  name               = each.key
  vault_role_name    = each.value.name
  pki_mount_path     = module.vault_pki_setup.vault_pki_path
  approle_mount_path = module.vault_pki_setup.auth_backend_paths["approle"]
  extra_policy_hcl   = lookup(local.workload_identity_extra_policies, each.key, "")
}

module "vault_workload_identity_dependencies" {

  source     = "../../modules/configuration/vault-workload-identity"
  providers = {
    vault = vault.production
  }
  depends_on = [module.vault_pki_setup]

  for_each           = local.dependency_roles
  name               = each.key
  vault_role_name    = each.value.name
  pki_mount_path     = module.vault_pki_setup.vault_pki_path
  approle_mount_path = module.vault_pki_setup.auth_backend_paths["approle"]
}
