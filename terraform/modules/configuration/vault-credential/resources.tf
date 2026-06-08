
terraform {
  required_providers {
    vault = {
      source                = "hashicorp/vault"
      configuration_aliases = [vault.production]
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

resource "random_password" "this" {
  for_each = var.generate

  length      = each.value.length
  special     = each.value.special
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = each.value.special ? 1 : 0
}

resource "vault_kv_secret_v2" "this" {
  provider = vault.production
  mount    = "secret"
  name     = "${var.vault_kv_namespace}/${var.domain}/${var.component}"

  data_json = jsonencode(merge(
    var.static,
    { for k, v in random_password.this : k => v.result }
  ))

}
