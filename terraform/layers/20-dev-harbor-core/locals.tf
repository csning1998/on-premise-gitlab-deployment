
locals {
  service_domain  = local.domain_list[0] # dev-harbor.iac.local
  vault_address   = "https://${data.terraform_remote_state.vault_core.outputs.vault_ha_virtual_ip}:443"
  vault_role_name = data.terraform_remote_state.vault_core.outputs.pki_configuration.ingress_roles.dev_harbor
  domain_list     = data.terraform_remote_state.vault_core.outputs.pki_configuration.ingress_domains.dev_harbor
}
