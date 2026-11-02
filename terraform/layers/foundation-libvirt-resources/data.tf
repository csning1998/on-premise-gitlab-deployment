
locals {
  network_allocation = nonsensitive(data.vault_generic_secret.registry_platform_network_allocation.data)
  network_baseline   = merge(jsondecode(local.network_allocation["network_baseline"]), { cidr_block = local.network_allocation["network_cidr"] })
}

# parent-group-governance publishes the domain suffix and the network baseline in the registry, in place of the state of platform-foundation.
data "vault_generic_secret" "registry_platform_network_allocation" {
  path = "registry/platform/network/allocation"
}
