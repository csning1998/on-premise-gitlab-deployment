
locals {

  minio_nodes_map = { for idx, config in var.minio_cluster_config.nodes.minio :
    "minio-node-${format("%02d", idx)}" => config
  }

  haproxy_nodes_map = { for idx, config in var.minio_cluster_config.nodes.haproxy :
    "minio-haproxy-node-${format("%02d", idx)}" => config
  }

  all_nodes_map = merge(
    local.minio_nodes_map,
    local.haproxy_nodes_map,
  )

  ansible_root_path = abspath("${path.root}/../../../ansible")

  minio_nat_network_subnet_prefix = join(".", slice(split(".", var.minio_infrastructure.network.nat.ips.address), 0, 3))
}
