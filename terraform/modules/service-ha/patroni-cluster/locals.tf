
locals {
  # Ansible execution path
  ansible_root_path = abspath("${path.root}/../../../ansible")

  # Gateway IP prefix extraction
  nat_network_subnet_prefix = join(".", slice(split(".", var.infra_config.network.nat.gateway), 0, 3))

  # Image Injection Logic
  # 1. Inject Postgres Base Image Path
  postgres_nodes_with_img = {
    for k, v in var.topology_config.postgres_config.nodes : k => merge(v, {
      base_image_path = var.topology_config.postgres_config.base_image_path
    })
  }

  # 2. Inject Etcd Base Image Path
  etcd_nodes_with_img = {
    for k, v in var.topology_config.etcd_config.nodes : k => merge(v, {
      base_image_path = var.topology_config.etcd_config.base_image_path
    })
  }

  # 3. Inject HAProxy Base Image Path
  haproxy_nodes_with_img = {
    for k, v in var.topology_config.haproxy_config.nodes : k => merge(v, {
      base_image_path = var.topology_config.haproxy_config.base_image_path
    })
  }

  # 4. Merge all
  all_nodes_map = merge(
    local.postgres_nodes_with_img,
    local.etcd_nodes_with_img,
    local.haproxy_nodes_with_img
  )
}
