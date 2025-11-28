
locals {

  minio_nodes_map = { for idx, config in var.minio_cluster_config.nodes.minio :
    "${var.minio_cluster_config.service_name}-minio-db-node-${format("%02d", idx)}" => config
  }
  # e.g. gitlab-minio-db-node-00, harbor-minio-db-node-00

  haproxy_nodes_map = { for idx, config in var.minio_cluster_config.nodes.haproxy :
    "${var.minio_cluster_config.service_name}-minio-haproxy-node-${format("%02d", idx)}" => config
  }
  # e.g. gitlab-minio-haproxy-node-00, harbor-minio-haproxy-node-00

  all_nodes_map = merge(
    local.minio_nodes_map,
    local.haproxy_nodes_map,
  )

  ansible_root_path = abspath("${path.root}/../../../ansible")

  minio_nat_network_subnet_prefix = join(".", slice(split(".", var.minio_infrastructure.network.nat.ips.address), 0, 3))
}
