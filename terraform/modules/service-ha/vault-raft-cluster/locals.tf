
locals {
  # Ansible path and network prefix calculation
  ansible_root_path = abspath("${path.root}/../../../ansible")

  # Gateway IP prefix extraction
  nat_network_subnet_prefix = join(".", slice(split(".", var.infra_config.network.nat.gateway), 0, 3))

  # 1. Inject Vault Base Image Path
  vault_nodes_with_img = {
    for k, v in var.topology_config.vault_config.nodes : k => merge(v, {
      base_image_path = var.topology_config.vault_config.base_image_path
    })
  }

  # 2. Inject HAProxy Base Image Path
  haproxy_nodes_with_img = {
    for k, v in var.topology_config.haproxy_config.nodes : k => merge(v, {
      base_image_path = var.topology_config.haproxy_config.base_image_path
    })
  }

  # Convert standard structure to Module 81 vm_config
  all_nodes_map = merge(
    local.vault_nodes_with_img,
    local.haproxy_nodes_with_img
  )
}
