
locals {

  all_nodes_map = { for idx, config in var.harbor_cluster_config.nodes.harbor :
    "harbor-node-${format("%02d", idx)}" => config
  }
  ansible_root_path = abspath("${path.root}/../../../ansible")

  harbor_nat_network_subnet_prefix = join(".", slice(split(".", var.harbor_infrastructure.network.nat.ips.address), 0, 3))
}
