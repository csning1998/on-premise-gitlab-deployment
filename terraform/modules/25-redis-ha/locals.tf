
locals {

  redis_nodes_map = { for idx, config in var.redis_cluster_config.nodes.redis :
    "${var.redis_cluster_config.service_name}-redis-node-db-${format("%02d", idx)}" => config
  }
  # e.g. gitlab-redis-node-db-00, harbor-redis-node-db-00

  redis_haproxy_nodes_map = { for idx, config in var.redis_cluster_config.nodes.haproxy :
    "${var.redis_cluster_config.service_name}-redis-haproxy-node-${format("%02d", idx)}" => config
  }
  # e.g. gitlab-redis-haproxy-node-00, harbor-redis-haproxy-node-00

  all_nodes_map = merge(
    local.redis_nodes_map,
    local.redis_haproxy_nodes_map
  )

  ansible_root_path = abspath("${path.root}/../../../ansible")

  redis_nat_network_subnet_prefix = join(".", slice(split(".", var.redis_infrastructure.network.nat.ips.address), 0, 3))
}
