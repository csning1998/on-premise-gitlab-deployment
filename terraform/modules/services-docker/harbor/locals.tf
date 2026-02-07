
locals {

  # Ansible path and network prefix calculation
  ansible_root_path = abspath("${path.root}/../../../ansible")

  # Gateway IP prefix extraction
  nat_network_subnet_prefix = join(".", slice(split(".", var.infra_config.network.nat.gateway), 0, 3))

  # Convert standard structure to Module 81 vm_config
  # 1. Inject Postgres Base Image Path
  dev_harbor_nodes_with_img = {
    for k, v in var.topology_config.dev_harbor_system_config.node : k => merge(v, {
      base_image_path = var.topology_config.dev_harbor_system_config.base_image_path
    })
  }
}
