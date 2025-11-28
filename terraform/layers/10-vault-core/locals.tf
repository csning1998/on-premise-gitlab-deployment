
locals {

  vault_nodes_map = { for idx, config in var.vault_cluster_config.nodes.vault :
    "vault-node-${format("%02d", idx)}" => config
  }

  haproxy_node = { for idx, config in var.vault_cluster_config.nodes.haproxy :
    "vault-haproxy-node-${format("%02d", idx)}" => config
  }
  all_nodes_map = merge(
    local.vault_nodes_map,
    local.haproxy_node
  )

  ansible_root_path = abspath("${path.root}/../../../ansible")

  vault_nat_network_subnet_prefix = join(".", slice(split(".", var.vault_infrastructure.network.nat.ips.address), 0, 3))
}
