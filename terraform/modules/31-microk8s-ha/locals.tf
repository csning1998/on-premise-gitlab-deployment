
locals {

  all_nodes_map = { for idx, config in var.microk8s_cluster_config.nodes.microk8s :
    "${var.microk8s_cluster_config.service_name}-microk8s-node-${format("%02d", idx)}" => config
  }
  # e.g. harbor-microk8s-node-00, gitlab-microk8s-node-00

  ansible_root_path = abspath("${path.root}/../../../ansible")

  microk8s_nat_network_subnet_prefix = join(".", slice(split(".", var.libvirt_infrastructure.network.nat.ips.address), 0, 3))
}
