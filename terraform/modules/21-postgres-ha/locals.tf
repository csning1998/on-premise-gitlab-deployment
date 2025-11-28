
locals {

  postgres_nodes_map = { for idx, config in var.postgres_cluster_config.nodes.postgres :
    "${var.postgres_cluster_config.service_name}-postgres-db-node-${format("%02d", idx)}" => config
  }
  # e.g. gitlab-postgres-db-node-00, harbor-postgres-db-node-00
  postgres_etcd_nodes_map = { for idx, config in var.postgres_cluster_config.nodes.etcd :
    "${var.postgres_cluster_config.service_name}-postgres-etcd-node-${format("%02d", idx)}" => config
  }
  # e.g. gitlab-postgres-etcd-node-00, harbor-postgres-etcd-node-00

  haproxy_nodes_map = { for idx, config in var.postgres_cluster_config.nodes.haproxy :
    "${var.postgres_cluster_config.service_name}-postgres-haproxy-node-${format("%02d", idx)}" => config
  }
  # e.g. gitlab-postgres-haproxy-node-00, harbor-postgres-haproxy-node-00

  all_nodes_map = merge(
    local.postgres_nodes_map,
    local.postgres_etcd_nodes_map,
    local.haproxy_nodes_map
  )

  ansible_root_path = abspath("${path.root}/../../../ansible")

  postgres_nat_network_subnet_prefix = join(".", slice(split(".", var.postgres_infrastructure.network.nat.ips.address), 0, 3))
}
