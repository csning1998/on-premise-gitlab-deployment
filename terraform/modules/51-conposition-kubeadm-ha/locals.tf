locals {

  ansible_root_path = abspath("${path.root}/../../../ansible")

  masters_node_map = { for idx, config in var.kubeadm_cluster_config.nodes.masters :
    "${var.kubeadm_cluster_config.service_name}-kubeadm-master-${format("%02d", idx)}" => config
  }
  # e.g. gitlab-kubeadm-master-00, harbor-kubeadm-master-00

  workers_node_map = { for idx, config in var.kubeadm_cluster_config.nodes.workers :
    "${var.kubeadm_cluster_config.service_name}-kubeadm-worker-${format("%02d", idx)}" => config
  }
  # e.g. gitlab-kubeadm-worker-00, harbor-kubeadm-worker-00

  all_nodes_map      = merge(local.masters_node_map, local.workers_node_map)
  kubeadm_master_ips = [for config in var.kubeadm_cluster_config.nodes.masters : config.ip]

  k8s_cluster_nat_network_subnet_prefix = join(".", slice(split(".", var.libvirt_infrastructure.network.nat.ips.address), 0, 3))
}
